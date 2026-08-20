require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in(users(:organizer_one))
  end

  test "creating an event assigns the signed-in organizer as its owner" do
    assert_difference("Event.count", 1) do
      post events_path, params: { event: { name: "Community Fun Run" } }
    end

    event = Event.order(:created_at).last
    assert_equal "Community Fun Run", event.name
    assert_equal users(:organizer_one), event.user
    assert_equal "created", event.status
  end

  test "a blank name is rejected" do
    assert_no_difference("Event.count") do
      post events_path, params: { event: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "starting an event makes it joinable" do
    event = events(:created_event)
    post start_event_path(event)
    assert_redirected_to event_path(event)
    assert event.reload.active?
  end

  test "any signed-in organizer can manage an event they didn't create" do
    sign_in(users(:organizer_two)) # organizer_two did not create created_event

    post start_event_path(events(:created_event))

    assert_redirected_to event_path(events(:created_event))
    assert events(:created_event).reload.active?
  end

  test "ending an event stops it from being joinable" do
    event = events(:active_event)
    post finish_event_path(event)
    assert event.reload.ended?
  end

  private

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end
end
