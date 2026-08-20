# Small, easily-tunable numbers that shape how the app behaves, pulled
# out here instead of buried as magic numbers scattered through the
# code. Ported straight from the original TypeScript app's
# src/core/policy.ts, same values, same reasoning -- these are exactly
# the kind of thing an organizer running a real event might want to
# retune without touching real logic.
module Policy
  # How many minutes after an event ends before its participants are
  # considered gone for good (used by the cleanup task, see
  # lib/tasks/event_retention.rake). Placeholder value, change this one
  # number to retune it.
  POST_EVENT_DISCONNECT_MINUTES = 20

  # How many minutes a participant's position has to sit essentially
  # unchanged before we'd flag them as possibly stuck, rather than just
  # on a normal break. Deliberately generous, so a real rest stop
  # doesn't trigger a false alarm.
  STUCK_DETECTION_WINDOW_MINUTES = 15

  # How far (in meters) someone has to move for it to count as "still
  # moving" rather than GPS jitter. Set comfortably above the drift a
  # stationary phone's GPS reading shows on its own.
  STUCK_DETECTION_MAX_DISTANCE_METERS = 30

  # How often (in seconds) a participant's position gets written into
  # the positions history table. Kept separate from how often the
  # browser sends a live update, since sampling every single live
  # update would make that table grow fast during a long event.
  HISTORY_SAMPLE_INTERVAL_SECONDS = 60

  # A signal reading older than this counts as "lost" for the map
  # dot's green/yellow/red status color, see GeoMath.signal_status.
  STALE_AFTER_SECONDS = 90

  # A GPS accuracy radius worse than this (in meters) counts as
  # "degraded" even if the reading itself is recent.
  DEGRADED_ACCURACY_METERS = 25
end
