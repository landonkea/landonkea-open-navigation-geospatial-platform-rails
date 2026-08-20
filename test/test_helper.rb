ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
# Turbo's own assert_turbo_stream_broadcasts helper lives in a file
# that isn't autoloaded by Rails (it's meant to be pulled in by hand
# in test_helper.rb, same as rails/test_help above), see
# test/models/participant_test.rb for where it actually gets used.
require "turbo/broadcastable/test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Pulls in assert_broadcasts/assert_broadcast_on/assert_no_broadcasts
    # everywhere, not just in dedicated channel tests -- several model
    # and controller tests below check that a change actually goes out
    # over Action Cable, not just that a database row changed.
    include ActionCable::TestHelper

    # Turbo's own test helper adds assert_turbo_stream_broadcasts, built
    # specifically for asserting on broadcast_replace_to/broadcast_append_to
    # calls like Participant#broadcast_roster_update makes -- it already
    # knows how to turn an [event, :roster] pair into the right stream
    # name, so tests don't have to reimplement that themselves.
    include Turbo::Broadcastable::TestHelper
  end
end
