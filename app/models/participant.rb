# One row per person currently in an event -- an actively-tracked
# member sharing their live position, or a spectator who's just
# watching. Nobody here has a User account; see
# app/controllers/event_joins_controller.rb for how a participant gets
# created and how we recognize the same person on their next visit.
#
# HOW WE KNOW A REQUEST OWNS THIS ROW (an improvement over the
# original app's design, worth calling out): the original TypeScript
# app trusted a client-generated id with no real way to verify it, its
# own schema comment says so plainly ("no login... trusts the client-
# generated id"). Rails gives us something better for free: when a
# participant joins, we store their participant id in a *signed*
# cookie (see Authentication::PARTICIPANT_COOKIE_PREFIX usage in
# EventJoinsController and PositionsController). A signed cookie can't
# be forged or edited by the browser -- only code that knows the
# app's secret key (config/credentials.yml.enc) could produce a valid
# one. So "does this request's cookie name this participant" is a real
# ownership check, not just a trust-based convention.
class Participant < ApplicationRecord
  belongs_to :event

  # This participant's own trail of past positions, oldest to newest.
  has_many :positions, dependent: :destroy

  validates :event, presence: true

  # Every time a participant row is created or changes (someone joins,
  # or an existing participant's position/status updates), push a
  # fresh copy of the roster list out to every browser watching this
  # event's map, so the "who's here" list updates live for everyone,
  # not just the person whose row changed. after_commit (not
  # after_save) on purpose: broadcasting before the transaction
  # actually commits could race a reader into looking up a row that
  # isn't there yet.
  after_commit :broadcast_roster_update, on: %i[create update]

  # Riders only, skipping spectators -- used anywhere we only care
  # about people actually being tracked (e.g. counting who's live on
  # the map).
  scope :riders, -> { where(is_spectator: false) }

  # True if this participant checked in recently enough to still count
  # as connected, using the same staleness window the map dot's own
  # green/yellow/red status uses (see GeoMath.signal_status).
  def online?
    last_seen_at.present? && Time.current - last_seen_at <= Policy::STALE_AFTER_SECONDS
  end

  # True if this participant has gone long enough without meaningfully
  # moving to be worth flagging to the organizer as possibly stuck --
  # a mechanical issue, an injury, or just waiting on a straggler, not
  # a normal quick stop. Ported from the original app's
  # src/core/stuckDetection.ts.
  def possibly_stuck?
    return false if is_spectator? || last_moved_at.nil?

    (Time.current - last_moved_at) > Policy::STUCK_DETECTION_WINDOW_MINUTES.minutes
  end

  # This participant's current signal status, delegating the actual
  # threshold logic to GeoMath so it stays in one tested place instead
  # of being reimplemented per-caller.
  def signal_status
    GeoMath.signal_status(last_seen_at, accuracy_m)
  end

  # A small hash shaped for turning into JSON for the live map --
  # exactly what the browser's JavaScript needs to draw or move this
  # participant's marker, nothing more. Pulled into one method so both
  # the initial page load and every later broadcast build this payload
  # the exact same way (see EventChannel and the map show view).
  def to_map_payload
    {
      id: id,
      lat: lat,
      lng: lng,
      heading_deg: heading_deg,
      color: color,
      tag: tag,
      is_spectator: is_spectator,
      status: signal_status
    }
  end

  private

  # The actual Turbo Stream broadcast, factored out of the after_commit
  # hook above so it's easy to read on its own. Every connected
  # browser has a <turbo-stream-source> subscribed to this exact
  # stream name (see the turbo_stream_from call in
  # app/views/maps/show.html.erb), Turbo replaces the "roster"
  # element's contents with whatever this partial renders, no
  # page-specific JavaScript required for this part.
  def broadcast_roster_update
    broadcast_replace_to(
      [ event, :roster ],
      target: "roster",
      partial: "events/roster",
      locals: { participants: event.participants.order(:created_at) }
    )
  end
end
