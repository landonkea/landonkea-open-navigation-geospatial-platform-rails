# This migration builds "positions" -- an append-only trail of where
# each participant has been over the course of an event. Distinct from
# the "current position" columns on participants (which get
# overwritten every update): this table gets a brand-new row every
# time, so a full route can be reconstructed and exported later.
# Mirrors the original app's "ride_history_samples" table.
class CreatePositions < ActiveRecord::Migration[8.1]
  def change
    create_table :positions do |t|
      # Which participant this sample belongs to.
      t.references :participant, null: false, foreign_key: true
      # Which event this sample belongs to -- duplicated from
      # participant.event_id on purpose (same as the original schema) so a
      # whole event's trail can be queried directly, without joining through
      # participants first.
      t.references :event, null: false, foreign_key: true
      # Where this participant was at the moment this sample was taken.
      # Not null: a position sample with no actual position isn't useful for
      # anything.
      t.float :lat, null: false
      t.float :lng, null: false
      # When this position was actually read on the person's device (not
      # "whenever the server happened to save it"), so an exported route
      # reflects real timing even if the write itself lands a bit late.
      t.datetime :recorded_at, null: false

      t.timestamps
    end
  end
end
