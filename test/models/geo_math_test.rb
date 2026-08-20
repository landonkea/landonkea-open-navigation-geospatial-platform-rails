require "test_helper"

class GeoMathTest < ActiveSupport::TestCase
  test "distance_meters is zero for the same point twice" do
    assert_in_delta 0, GeoMath.distance_meters(33.4152, -111.8315, 33.4152, -111.8315), 0.001
  end

  test "distance_meters matches the well-known length of one degree of latitude" do
    # Moving exactly 1 degree of latitude, due north from the equator,
    # covers a distance with a known, precise answer (radius times
    # angle in radians) -- a much more exact check than eyeballing two
    # real-world city coordinates.
    expected_meters = GeoMath::EARTH_RADIUS_METERS * (Math::PI / 180)

    distance = GeoMath.distance_meters(0, 0, 1, 0)

    assert_in_delta expected_meters, distance, 1
  end

  test "real_movement? is false for movement smaller than the reading's own accuracy" do
    assert_not GeoMath.real_movement?(5, 20) # moved 5m, but the reading itself could be off by 20m
  end

  test "real_movement? is true once movement exceeds the reading's own accuracy" do
    assert GeoMath.real_movement?(25, 20)
  end

  test "signal_status is red with no update at all" do
    assert_equal "red", GeoMath.signal_status(nil, 5)
  end

  test "signal_status is red once an update is older than the stale threshold" do
    now = Time.current
    stale_at = now - (Policy::STALE_AFTER_SECONDS + 10).seconds
    assert_equal "red", GeoMath.signal_status(stale_at, 5, now: now)
  end

  test "signal_status is yellow for a recent but low-accuracy reading" do
    now = Time.current
    assert_equal "yellow", GeoMath.signal_status(now - 5.seconds, Policy::DEGRADED_ACCURACY_METERS + 1, now: now)
  end

  test "signal_status is green for a recent, accurate reading" do
    now = Time.current
    assert_equal "green", GeoMath.signal_status(now - 5.seconds, 5, now: now)
  end
end
