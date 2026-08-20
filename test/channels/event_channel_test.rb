require "test_helper"

class EventChannelTest < ActionCable::Channel::TestCase
  test "subscribes to the requested event's own stream" do
    event = events(:active_event)
    stub_connection

    subscribe(event_slug: event.slug)

    assert subscription.confirmed?
    assert_has_stream_for event
  end

  test "rejects a subscription for an event slug that doesn't exist" do
    stub_connection

    subscribe(event_slug: "no-such-event")

    assert subscription.rejected?
  end

  test "a broadcast to the event is delivered to everyone subscribed to it" do
    event = events(:active_event)
    payload = participants(:rider_one).to_map_payload
    stub_connection
    subscribe(event_slug: event.slug)

    assert_broadcast_on(event, payload) do
      EventChannel.broadcast_to(event, payload)
    end
  end
end
