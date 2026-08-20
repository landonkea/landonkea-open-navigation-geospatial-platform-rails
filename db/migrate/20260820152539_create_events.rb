# This migration builds the "events" table -- one row per group event
# (a ride, a hike, a kiosk session, whatever the organizer is running).
# It mirrors the original TypeScript app's "rides" table, renamed to
# the more generic "events" since this platform isn't just for cycling.
class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    # create_table opens up the new table and everything inside the
    # block describes one column each.
    create_table :events do |t|
      # The organizer-facing name shown everywhere, e.g. "Saturday Morning Loop".
      t.string :name, null: false
      # The short, human-typeable link segment (e.g. "08202026") people actually
      # visit to join -- see app/models/event.rb for how it gets generated.
      # Never null: every event needs a real join link the moment it's created.
      t.string :slug, null: false
      # Where this event is in its lifecycle. Stored as plain text with a
      # database-level check constraint below (not just app-side validation),
      # so a bad status can never sneak in even from a rogue script or console.
      t.string :status, null: false, default: "created"
      # Who created/manages this event -- the signed-in organizer's account.
      # foreign_key: true makes the database itself reject an event row that
      # points at a user id which doesn't exist.
      t.references :user, null: false, foreign_key: true
      # Stamped the moment an organizer flips the event from "created" to
      # "active" -- null until then, meaning "hasn't started yet."
      t.datetime :started_at
      # Stamped the moment an organizer ends the event -- null while it's
      # still created/active.
      t.datetime :ended_at

      # created_at/updated_at, added automatically by Rails on every table.
      t.timestamps
    end

    # A unique index means the database itself refuses two events with the
    # same slug, not just our Ruby validation -- belt and suspenders.
    add_index :events, :slug, unique: true

    # A real SQL constraint (not just a Ruby-side check) limiting status to
    # these three values, so even a raw SQL insert can't create a bogus
    # status. Matches the original schema's own status check constraint.
    add_check_constraint :events, "status IN ('created', 'active', 'ended')", name: "events_status_check"
  end
end
