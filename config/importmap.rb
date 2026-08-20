# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# Makes "channels/consumer" resolvable as an import specifier -- without
# this line, the browser has no idea where "channels/consumer" (used by
# live_map_controller.js) is actually supposed to come from.
pin_all_from "app/javascript/channels", under: "channels"
pin "@rails/actioncable", to: "@rails--actioncable.js" # @7.2.302

# MapLibre ships as a real ES module that internally imports a second
# "shared chunk" file as a plain sibling (`import ... from
# "./maplibre-gl-shared.mjs"`) -- normal for how the library's own
# build works, but Rails' asset pipeline (Propshaft) only ever serves
# files at their fingerprinted URL, and has no way to know it should
# rewrite that plain, un-fingerprinted reference buried inside a
# third-party file. Vendoring both files locally with `bin/importmap
# pin` hits exactly that mismatch: MapLibre loads, then its own
# internal import 404s. Pointing straight at jsDelivr instead sidesteps
# the problem entirely -- both files sit there at their real,
# unmodified relative paths, exactly what MapLibre's own code expects.
pin "maplibre-gl", to: "https://cdn.jsdelivr.net/npm/maplibre-gl@6.4.0/dist/maplibre-gl.mjs", preload: true
