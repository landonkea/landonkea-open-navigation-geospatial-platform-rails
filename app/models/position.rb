# One row per recorded trail point -- unlike participant.lat/lng
# (which gets overwritten on every check-in), a new Position row gets
# added every time, building up a full history of where someone's
# been over the course of an event. See PositionsController for the
# throttling that keeps this table from growing on every single live
# update (Policy::HISTORY_SAMPLE_INTERVAL_SECONDS).
class Position < ApplicationRecord
  belongs_to :participant
  belongs_to :event

  validates :lat, :lng, :recorded_at, presence: true
end
