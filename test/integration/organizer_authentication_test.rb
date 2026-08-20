require "test_helper"

class OrganizerAuthenticationTest < ActionDispatch::IntegrationTest
  test "signing in with the right email and password grants access to organizer pages" do
    get new_session_path
    assert_response :success

    post session_path, params: { email_address: users(:organizer_one).email_address, password: "password123" }
    assert_redirected_to root_url

    get events_path
    assert_response :success
  end

  test "signing in with the wrong password is rejected" do
    post session_path, params: { email_address: users(:organizer_one).email_address, password: "not-the-password" }
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match(/Try another email address or password/i, response.body)
  end

  test "organizer-only pages redirect an anonymous visitor to sign in" do
    get events_path
    assert_redirected_to new_session_path
  end

  test "signing out ends the session" do
    post session_path, params: { email_address: users(:organizer_one).email_address, password: "password123" }
    assert_redirected_to root_url

    delete session_path
    get events_path
    assert_redirected_to new_session_path
  end

  test "the public map and home page never require organizer sign-in" do
    get root_path
    assert_response :success

    get event_map_path(events(:active_event))
    assert_response :success
  end
end
