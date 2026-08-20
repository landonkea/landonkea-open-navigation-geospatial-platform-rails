# The public side of the app: opening a join link, choosing rider vs.
# spectator, watching the live map, and leaving. Nobody here has an
# account, which is why allow_unauthenticated_access is called below
# to opt this whole controller out of ApplicationController's default
# "you must be signed in" rule.
class MapsController < ApplicationController
  allow_unauthenticated_access
  include ParticipantIdentity

  before_action :set_event

  # Shows one of three things, decided by the view: a "hasn't started
  # yet" message (event still in "created" status), the live map (a
  # returning visitor we already recognize via their signed cookie),
  # or the "how are you joining" choice screen (a brand-new visitor to
  # an active event). Keeping that branching in the view instead of
  # rendering three different templates from here keeps this action
  # trivial and puts the actual decision next to the markup it affects.
  def show
    @participant = current_participant
  end

  # Creates this browser's participant row for the event and remembers
  # it with a signed cookie (see ParticipantIdentity) so later visits
  # -- including a page reload mid-event -- recognize the same person
  # instead of creating a second row.
  def join
    unless @event.joinable?
      redirect_to event_map_path(@event), alert: "This event isn't accepting new joiners right now." and return
    end

    participant = @event.participants.create!(
      # mode="rider" means "I'm sharing my location"; anything else
      # (including a missing/blank value) is treated as "just
      # watching" -- the safer default when we're not sure what was
      # actually chosen.
      is_spectator: params[:mode] != "rider",
      tag: params[:tag].presence,
      color: params[:color].presence,
      last_seen_at: Time.current,
      last_moved_at: Time.current
    )
    remember_participant(participant)
    redirect_to event_map_path(@event)
  end

  # An explicit "leave" action, so someone's dot disappears for
  # everyone else right away instead of sitting on the map until a
  # future cleanup job eventually notices they've gone quiet.
  def leave
    current_participant&.destroy
    forget_participant(@event)
    redirect_to event_map_path(@event)
  end

  private

  def set_event
    @event = Event.find_by(slug: params[:event_slug])
    redirect_to root_path, alert: "That event link doesn't work anymore." unless @event
  end
end
