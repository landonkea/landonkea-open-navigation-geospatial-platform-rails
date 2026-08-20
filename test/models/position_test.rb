require "test_helper"

class PositionTest < ActiveSupport::TestCase
  test "valid with lat, lng, recorded_at, a participant, and an event" do
    position = Position.new(
      participant: participants(:rider_one),
      event: events(:active_event),
      lat: 33.41,
      lng: -111.83,
      recorded_at: Time.current
    )
    assert position.valid?
  end

  test "requires lat, lng, and recorded_at" do
    position = Position.new(participant: participants(:rider_one), event: events(:active_event))
    assert_not position.valid?
    assert_includes position.errors[:lat], "can't be blank"
    assert_includes position.errors[:lng], "can't be blank"
    assert_includes position.errors[:recorded_at], "can't be blank"
  end
end
