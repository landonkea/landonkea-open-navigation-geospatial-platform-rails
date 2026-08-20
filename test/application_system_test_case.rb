require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # The live map page renders real WebGL (that's how MapLibre draws the
  # map itself), but headless Chrome has no real GPU to hand it -- with
  # no extra flags it just refuses to create a WebGL context at all.
  # These two flags tell Chrome to fall back to SwiftShader, a
  # software (CPU-based) GL implementation, so the map still actually
  # renders during a test run instead of failing with a "WebGL2 is
  # required" error the moment the page tries to draw it.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |driver_option|
    driver_option.add_argument("--use-angle=swiftshader")
    driver_option.add_argument("--enable-unsafe-swiftshader")
  end
end
