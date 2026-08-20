require "test_helper"

class ParticipantTest < ActiveSupport::TestCase
  test "requires an event" do
    participant = Participant.new
    assert_not participant.valid?
    assert_includes participant.errors[:event], "must exist"
  end

  test "riders scope excludes spectators" do
    riders = Participant.riders
    assert_includes riders, participants(:rider_one)
    assert_not_includes riders, participants(:spectator_one)
  end

  test "online? is true only within the staleness window" do
    rider = participants(:rider_one) # last_seen_at is 30 seconds ago in fixtures
    assert rider.online?

    rider.last_seen_at = 10.minutes.ago
    assert_not rider.online?
  end

  test "possibly_stuck? is false for a spectator regardless of last_moved_at" do
    spectator = participants(:spectator_one)
    spectator.last_moved_at = 1.hour.ago
    assert_not spectator.possibly_stuck?
  end

  test "possibly_stuck? is true once someone hasn't moved past the tuned window" do
    rider = participants(:rider_one)
    rider.last_moved_at = (Policy::STUCK_DETECTION_WINDOW_MINUTES + 5).minutes.ago
    assert rider.possibly_stuck?

    rider.last_moved_at = 1.minute.ago
    assert_not rider.possibly_stuck?
  end

  test "to_map_payload has exactly what the browser's JS needs to draw a marker" do
    rider = participants(:rider_one)
    payload = rider.to_map_payload

    assert_equal rider.id, payload[:id]
    assert_equal rider.lat, payload[:lat]
    assert_equal rider.lng, payload[:lng]
    assert_equal rider.is_spectator, payload[:is_spectator]
    assert_includes %w[green yellow red], payload[:status]
  end

  test "creating a participant broadcasts the roster live to anyone watching the event" do
    event = events(:active_event)

    assert_turbo_stream_broadcasts([ event, :roster ], count: 1) do
      event.participants.create!(is_spectator: true)
    end
  end
end
