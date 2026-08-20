# This migration builds "participants" -- one row per person currently
# in an event, whether they're an actively-tracked member or a
# spectator who's just watching. Mirrors the original app's
# "ride_participants" table. Unlike the organizer (a real logged-in
# User), a participant never creates an account -- see
# app/models/participant.rb and app/controllers/event_joins_controller.rb
# for how a signed, tamper-proof cookie stands in for a login here.
class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants do |t|
      # Which event this person joined. foreign_key: true means deleting an
      # event cleans up its participants automatically at the database level
      # (paired with dependent: :destroy on the Event model's association).
      t.references :event, null: false, foreign_key: true
      # True if this person is just watching, never sharing their own
      # location (either they chose "just watching," or their browser
      # denied/couldn't get a location fix). Defaults to false: the common
      # case is someone actively sharing their position.
      t.boolean :is_spectator, null: false, default: false
      # An optional free-text label the person picked for themselves on the
      # join screen (e.g. "marshal," "photographer"). Left as plain text
      # rather than a fixed list so new tags don't need a migration.
      t.string :tag
      # Latitude/longitude of this participant's current position. Both stay
      # null until their first real GPS reading comes in (a brand-new
      # spectator, or a rider whose phone hasn't reported yet).
      t.float :lat
      t.float :lng
      # GPS accuracy radius in meters, straight from the browser's
      # Geolocation API -- drives the "how confident is this dot" signal.
      t.float :accuracy_m
      # Compass heading and ground speed, both derived client-side by
      # comparing this reading to the previous one (see the position update
      # JS), null until there's a second reading to compare against.
      t.float :heading_deg
      t.float :speed_mps
      # When this participant's phone last successfully checked in -- powers
      # the "still connected" vs. "gone quiet" status on the map.
      t.datetime :last_seen_at
      # When this participant actually last MOVED (not just checked in),
      # separate from last_seen_at above -- someone can have perfect signal
      # while standing still. Used for a future "possibly stuck" flag.
      t.datetime :last_moved_at
      # An optional hex color (e.g. "#2196f3") the person picked for their
      # own map marker, purely cosmetic, never used to identify or
      # authenticate anyone.
      t.string :color

      # created_at effectively doubles as "joined_at" here -- when this row
      # was first written is exactly when this person joined the event.
      t.timestamps
    end
  end
end
