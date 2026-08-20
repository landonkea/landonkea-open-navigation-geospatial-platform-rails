# One row per group event -- a ride, a hike, a kiosk session, whatever
# an organizer is running. This is the generic replacement for the
# original app's bike-specific "ride" concept: same idea, same
# lifecycle, just not assuming everyone showing up is on a bicycle.
#
# SECURITY MODEL, worth stating plainly (same honest tradeoff the
# original schema's own top-of-file comment makes): regular
# participants never log in, so `slug` below is effectively this
# event's join secret -- whoever has the link can view the map and
# join. That's deliberate, not an oversight: it matches the low-
# friction, no-account design this whole platform is built around. See
# app/models/participant.rb for how we do better than the original on
# the OTHER half of that tradeoff (proving you own your own
# participant row, not just that you have the event's link).
class Event < ApplicationRecord
  # The organizer who created and manages this event -- a real,
  # logged-in User account (see app/models/user.rb).
  belongs_to :user

  # Every person who has joined this event, riders and spectators
  # alike. dependent: :destroy means deleting an event cleans up every
  # participant row that belonged to it, no orphaned rows left behind.
  has_many :participants, dependent: :destroy

  # The full position history across every participant in this event,
  # same dependent: :destroy cleanup reasoning as participants above.
  has_many :positions, dependent: :destroy

  # The three states an event moves through, in order, matching the
  # database's own check constraint from the migration -- kept here
  # too so Ruby-level validation catches a bad status before it ever
  # reaches the database.
  STATUSES = %w[created active ended].freeze

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :slug, presence: true, uniqueness: true

  # Fills in a real, unique slug before the very first save, so nobody
  # calling Event.create! ever has to think about generating one
  # themselves -- see generate_unique_slug below for the actual logic.
  before_validation :assign_slug, on: :create

  # Rails calls to_param whenever it needs to turn a record into a URL
  # segment (redirect_to @event, event_path(@event), and so on).
  # Overriding it to return the slug instead of the numeric id means
  # every route in this app "just works" with human-friendly,
  # non-sequential links, without every controller having to remember
  # to look events up by slug by hand.
  def to_param
    slug
  end

  # A tiny convenience so views/controllers can write `event.active?`
  # instead of the more awkward `event.status == "active"` everywhere.
  def active?
    status == "active"
  end

  def ended?
    status == "ended"
  end

  # True once an event is far enough along that new people can still
  # join it -- matches the original schema's "anyone can join an
  # active ride" rule: not before it's started, not after it's ended.
  def joinable?
    active?
  end

  # Flips a freshly-created event into its live, joinable state and
  # stamps when that happened. Kept as its own method (instead of
  # `update!(status: "active")` scattered wherever it's called) so
  # there's exactly one place that knows what "starting" an event
  # actually means.
  def start!
    update!(status: "active", started_at: Time.current)
  end

  # The mirror image of start! above -- stops the event and stamps
  # when. Participants' browsers notice this on their next check-in
  # (see PositionsController) and stop sharing location.
  def end!
    update!(status: "ended", ended_at: Time.current)
  end

  private

  # Builds today's date-based slug (e.g. "08202026") and, if another
  # event was already created today, appends "-2", "-3", and so on
  # until a free one is found. Ported from the original app's
  # src/core/rideSlug.ts -- same format, same honest tradeoff: a date
  # is short and easy to read off a QR code or type by hand, but it's
  # guessable in a way a random token wouldn't be. Accepted here for
  # the same low-friction reasons the original accepted it.
  def assign_slug
    return if slug.present? # someone already set one explicitly, leave it alone

    base = Time.current.strftime("%m%d%Y") # e.g. "08202026", month/day/4-digit year, no separators
    candidate = base
    suffix = 2
    # Keep trying "-2", "-3", ... until we land on one nobody's using.
    # Starts at 2, not 1, so the first event of the day keeps the
    # clean, no-suffix slug.
    while Event.exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end
end
