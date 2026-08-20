require "test_helper"

class PositionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:active_event)
  end

  test "a recognized participant's position update saves and broadcasts live" do
    rider = join_as_rider(@event)

    assert_broadcasts(EventChannel.broadcasting_for(@event), 1) do
      post event_positions_path(@event), params: { lat: "33.42", lng: "-111.84", accuracy_m: "8" }
    end

    assert_response :success
    rider.reload
    assert_in_delta 33.42, rider.lat, 0.0001
    assert_in_delta(-111.84, rider.lng, 0.0001)
  end

  test "moving far enough bumps last_moved_at, a tiny jitter-sized move does not" do
    rider = join_as_rider(@event)
    # Give this brand-new participant a known starting point instead of
    # the nil lat/lng they join with, so both requests below are
    # measuring real movement against a real previous position.
    rider.update!(lat: 33.4152, lng: -111.8315, last_moved_at: 1.hour.ago)
    original_last_moved_at = rider.last_moved_at

    # 1 meter of "movement" with a 50m accuracy reading is well inside
    # GPS noise, should NOT count as real movement.
    post event_positions_path(@event), params: { lat: rider.lat, lng: rider.lng, accuracy_m: "50" }
    rider.reload
    assert_in_delta original_last_moved_at.to_f, rider.last_moved_at.to_f, 1.0

    # A real, multi-hundred-meter jump with a tight 5m accuracy
    # reading clearly IS real movement.
    post event_positions_path(@event), params: { lat: (rider.lat + 0.01), lng: rider.lng, accuracy_m: "5" }
    rider.reload
    assert_operator rider.last_moved_at, :>, original_last_moved_at
  end

  test "a request with no participant cookie is rejected" do
    post event_positions_path(@event), params: { lat: "1", lng: "1" }
    assert_response :unauthorized
  end

  test "a spectator's browser is refused even if it tries" do
    join_as_spectator(@event)

    post event_positions_path(@event), params: { lat: "1", lng: "1" }
    assert_response :unprocessable_entity
  end

  test "an ended event refuses new position updates" do
    # Join while the event is still active (an organizer can't have
    # ended it before anyone joined in the first place), then end it
    # out from under this already-joined rider, mirroring what
    # actually happens when an organizer hits "End event" mid-way
    # through.
    join_as_rider(@event)
    @event.end!

    post event_positions_path(@event), params: { lat: "1", lng: "1" }
    assert_response :gone
  end

  private

  # Joins for real, through the actual join endpoint, exactly like a
  # real browser would -- this is what actually sets the signed
  # participant cookie via Set-Cookie, which the integration test's
  # own cookie jar then carries into every request that follows in the
  # same test. Trying to fabricate that signed cookie value by hand
  # instead would mean re-implementing Rails' own cookie-signing
  # internals just for a test, not worth it when the real endpoint
  # does the job in one line.
  def join_as_rider(event)
    post event_join_path(event), params: { mode: "rider" }
    Participant.order(:created_at).last
  end

  def join_as_spectator(event)
    post event_join_path(event), params: { mode: "spectator" }
    Participant.order(:created_at).last
  end
end
