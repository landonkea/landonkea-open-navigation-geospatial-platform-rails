require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "requires a name" do
    event = Event.new(user: users(:organizer_one))
    assert_not event.valid?
    assert_includes event.errors[:name], "can't be blank"
  end

  test "generates its own slug when none is given" do
    event = Event.create!(name: "Auto Slug Test", user: users(:organizer_one))
    assert_match(/\A\d{8}(-\d+)?\z/, event.slug)
  end

  test "appends a numeric suffix when today's plain slug is already taken" do
    first = Event.create!(name: "First today", user: users(:organizer_one))
    second = Event.create!(name: "Second today", user: users(:organizer_one))

    assert_match(/\A\d{8}\z/, first.slug) # the first event of the day keeps the clean, no-suffix slug
    assert_equal "#{first.slug}-2", second.slug # the second collides, so it gets a suffix
  end

  test "to_param returns the slug, not the numeric id, so URLs never expose it" do
    event = events(:active_event)
    assert_equal event.slug, event.to_param
  end

  test "start! flips status to active and stamps started_at" do
    event = events(:created_event)
    assert_nil event.started_at

    event.start!

    assert_equal "active", event.status
    assert_not_nil event.started_at
  end

  test "end! flips status to ended and stamps ended_at" do
    event = events(:active_event)

    event.end!

    assert_equal "ended", event.status
    assert_not_nil event.ended_at
  end

  test "joinable? is only true while active" do
    assert_not events(:created_event).joinable?
    assert events(:active_event).joinable?
    assert_not events(:ended_event).joinable?
  end

  test "deleting an event deletes its participants and positions too" do
    event = events(:active_event)
    participant_ids = event.participants.pluck(:id)
    assert participant_ids.any?

    event.destroy!

    assert_empty Participant.where(id: participant_ids)
    assert_empty Position.where(event_id: event.id)
  end
end
