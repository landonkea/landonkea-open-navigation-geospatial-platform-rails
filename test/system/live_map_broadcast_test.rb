require "application_system_test_case"

# This is the test the whole real-time design rests on: does an update
# to one participant actually reach a DIFFERENT, already-open browser
# session live, with no page reload? Everything else (models, the
# channel in isolation, the controller) can be correct on paper and
# this could still be broken if the wiring between them -- the Turbo
# Stream broadcast, Solid Cable, the websocket connection -- isn't
# actually working end to end. A real Selenium-driven browser is what
# makes this a genuine end-to-end proof, not a simulation of one.
class LiveMapBroadcastTest < ApplicationSystemTestCase
  test "another participant's update appears on an already-open map with no reload" do
    event = events(:active_event)

    # This browser joins as a spectator and sits on the live map page,
    # exactly like a real person watching the event unfold.
    visit event_map_path(event)
    choose "Just watching"
    click_on "Join event"
    assert_text "Watching live"

    # Confirm the roster starts out with the fixture participants
    # already in the event, before anything new happens.
    within "#roster" do
      assert_text "Participant ##{participants(:rider_one).id}"
    end

    # Simulate what PositionsController#create does after a rider's
    # phone checks in -- update the row directly, from the test
    # process, completely outside this browser. If the roster below
    # updates without us ever telling Capybara to reload the page,
    # that update really did travel over a live websocket connection,
    # not just get rendered because the page happened to be fresh.
    participants(:rider_one).update!(tag: "leading the group")

    within "#roster" do
      assert_text "leading the group"
    end
  end
end
