# Where a participant's own browser posts a fresh GPS reading. This is
# the single busiest endpoint in the app -- it gets hit on a timer by
# every actively-tracked rider's phone -- so it stays deliberately
# small: update this device's own row, maybe log a history sample,
# broadcast the update, done. No page render, just a small JSON reply.
class PositionsController < ApplicationController
  allow_unauthenticated_access
  include ParticipantIdentity

  before_action :set_event
  before_action :set_participant

  def create
    return render json: { error: "not_joined" }, status: :unauthorized unless @participant
    return render json: { error: "event_not_active" }, status: :gone unless @event.active?
    # A spectator's browser should never be calling this endpoint at
    # all (see live_map_controller.js, it only starts sending updates
    # for riders), but a stale tab or a replayed request could still
    # try, so this is a real guard, not just documentation.
    return render json: { error: "spectators_do_not_share_location" }, status: :unprocessable_entity if @participant.is_spectator?

    lat = params.require(:lat).to_f
    lng = params.require(:lng).to_f
    accuracy_m = params[:accuracy_m].presence&.to_f
    heading_deg = params[:heading_deg].presence&.to_f
    speed_mps = params[:speed_mps].presence&.to_f

    # "Did this reading actually move, or is it just GPS jitter from
    # standing still?" -- a brand-new participant with no prior
    # position always counts as movement (there's nothing to compare
    # against yet), everyone else gets the real accuracy-aware check.
    moved =
      if @participant.lat.nil? || @participant.lng.nil?
        true
      else
        distance = GeoMath.distance_meters(@participant.lat, @participant.lng, lat, lng)
        GeoMath.real_movement?(distance, accuracy_m || 0)
      end

    @participant.update!(
      lat: lat,
      lng: lng,
      accuracy_m: accuracy_m,
      heading_deg: heading_deg,
      speed_mps: speed_mps,
      last_seen_at: Time.current,
      # Only bumped forward on real movement -- left alone otherwise,
      # so it keeps reflecting whenever this person genuinely last
      # moved, not just whenever they last checked in.
      last_moved_at: moved ? Time.current : @participant.last_moved_at
    )

    record_history_sample_if_due(lat, lng)

    # Push this update out to every other browser watching this
    # event's live map right now -- see app/channels/event_channel.rb
    # for what's actually listening on the other end.
    EventChannel.broadcast_to(@event, @participant.to_map_payload)

    render json: { ok: true, event_status: @event.status }
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  end

  private

  def set_event
    @event = Event.find_by(slug: params[:event_slug])
    render json: { error: "event_not_found" }, status: :not_found unless @event
  end

  def set_participant
    @participant = current_participant if @event
  end

  # Writes a permanent trail point roughly once a minute per
  # participant (Policy::HISTORY_SAMPLE_INTERVAL_SECONDS), separate
  # from the "current position" update above which happens on every
  # single check-in. Sampling that often on every check-in would make
  # this table grow fast over a long event for no real benefit -- a
  # once-a-minute trail is plenty to reconstruct where someone went.
  def record_history_sample_if_due(lat, lng)
    last_sample = @participant.positions.order(recorded_at: :desc).first
    due = last_sample.nil? || (Time.current - last_sample.recorded_at) >= Policy::HISTORY_SAMPLE_INTERVAL_SECONDS
    return unless due

    @participant.positions.create!(event: @event, lat: lat, lng: lng, recorded_at: Time.current)
  end
end
