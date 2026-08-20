require "test_helper"

class MapsControllerTest < ActionDispatch::IntegrationTest
  test "visiting an active event's join link with no cookie shows the choose screen" do
    get event_map_path(events(:active_event))
    assert_response :success
    assert_select "input[value=rider]"
  end

  test "an event that hasn't started yet shows a not-started message instead of a join screen" do
    get event_map_path(events(:created_event))
    assert_response :success
    assert_no_match(/how would you like to join/i, response.body)
  end

  test "joining as a spectator never creates a lat/lng and never requests location" do
    assert_difference("Participant.count", 1) do
      post event_join_path(events(:active_event)), params: { mode: "spectator" }
    end

    participant = Participant.order(:created_at).last
    assert participant.is_spectator?
    assert_nil participant.lat
  end

  test "a returning visitor with a join cookie sees the live map, not the choose screen again" do
    post event_join_path(events(:active_event)), params: { mode: "spectator" }

    assert_no_difference("Participant.count") do
      get event_map_path(events(:active_event)) # same browser, cookie already set from the join above
    end

    assert_response :success
    assert_no_match(/how would you like to join/i, response.body)
  end

  test "joining an event that hasn't started is refused" do
    assert_no_difference("Participant.count") do
      post event_join_path(events(:created_event)), params: { mode: "rider" }
    end
  end

  test "leaving removes the participant row" do
    post event_join_path(events(:active_event)), params: { mode: "spectator" }
    participant = Participant.order(:created_at).last

    assert_difference("Participant.count", -1) do
      delete event_leave_path(events(:active_event))
    end
    assert_not Participant.exists?(participant.id)
  end
end
