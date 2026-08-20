# Plain math on GPS coordinates -- distance, real-vs-noise movement,
# and signal-status color. No database, no HTTP, nothing but numbers
# in and numbers out, which is exactly what makes it easy to write
# solid tests against (see test/models/geo_math_test.rb). Ported from
# the original TypeScript app's src/core/geo.ts, same formulas, same
# thresholds.
module GeoMath
  # The Earth's radius in meters -- the Haversine formula below needs
  # this to turn an angle into an actual distance.
  EARTH_RADIUS_METERS = 6_371_000

  # Converts degrees to radians, since Ruby's trig functions (like
  # every language's) work in radians, but GPS coordinates always
  # arrive in plain degrees.
  def self.to_radians(degrees)
    degrees * Math::PI / 180
  end

  # Distance in meters between two {lat, lng} points, using the
  # Haversine formula -- the standard way to measure distance on a
  # sphere, which accounts for the Earth's curvature (a naive
  # Pythagorean distance would be visibly wrong at real-world scale).
  def self.distance_meters(a_lat, a_lng, b_lat, b_lng)
    lat1 = to_radians(a_lat)
    lat2 = to_radians(b_lat)
    delta_lat = to_radians(b_lat - a_lat)
    delta_lng = to_radians(b_lng - a_lng)

    # The "half versed sine" of the central angle between the two points --
    # this is the heart of the Haversine formula.
    haversine = (Math.sin(delta_lat / 2)**2) +
      (Math.cos(lat1) * Math.cos(lat2) * (Math.sin(delta_lng / 2)**2))
    central_angle = 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine))

    EARTH_RADIUS_METERS * central_angle # arc length = radius times angle, gives meters
  end

  # Whether a fresh reading, this many meters from the last one we
  # actually showed, represents real movement rather than GPS noise.
  # A reading's own accuracy radius IS its uncertainty -- movement
  # smaller than that radius can't be told apart from noise, so it
  # doesn't count as real.
  def self.real_movement?(distance_moved_meters, new_reading_accuracy_m)
    distance_moved_meters > new_reading_accuracy_m
  end

  # The three signal states a participant's map dot can show. Red
  # means "no update in a while, effectively lost." Yellow means
  # "recent, but the GPS fix itself is poor." Green is the good case.
  def self.signal_status(last_update_at, last_accuracy_m, now: Time.current)
    return "red" if last_update_at.nil?

    age_seconds = now - last_update_at
    return "red" if age_seconds > Policy::STALE_AFTER_SECONDS
    return "yellow" if last_accuracy_m && last_accuracy_m > Policy::DEGRADED_ACCURACY_METERS

    "green"
  end
end
