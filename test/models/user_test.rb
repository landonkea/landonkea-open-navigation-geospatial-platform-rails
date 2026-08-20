require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "won't allow two accounts with the same email" do
    duplicate = User.new(email_address: users(:organizer_one).email_address, password: "somethingelse123")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email_address], "has already been taken"
  end

  test "normalizes email address casing and whitespace" do
    user = User.create!(email_address: "  Someone@Example.com  ", password: "password123")
    assert_equal "someone@example.com", user.email_address
  end

  test "authenticates only with the correct password" do
    user = users(:organizer_one)
    assert user.authenticate("password123")
    assert_not user.authenticate("wrong-password")
  end

  test "deleting an organizer deletes their events too" do
    user = users(:organizer_one)
    event_ids = user.events.pluck(:id)
    assert event_ids.any?

    user.destroy!

    assert_empty Event.where(id: event_ids)
  end
end
