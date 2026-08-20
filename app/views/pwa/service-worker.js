// A deliberately small service worker -- just enough to make the app
// genuinely installable (add-to-home-screen) and let it start loading
// straight from cache when connectivity is briefly rocky, which
// matters a lot for something meant to be used out on a trail with
// spotty signal. It is NOT trying to make the live map itself work
// offline -- positions and the map's own tiles still need a real
// network connection, this only protects the app's own shell (the
// page layout, styles, and scripts) from a flaky connection getting
// in the way of the page loading at all.

const SHELL_CACHE_NAME = "open-nav-shell-v1"

// Only the page shell itself -- deliberately NOT caching API responses
// like /e/:slug/positions, those need to always hit the real server.
const SHELL_URLS = ["/", "/manifest"]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(SHELL_CACHE_NAME).then((cache) => cache.addAll(SHELL_URLS))
  )
})

self.addEventListener("activate", (event) => {
  // Clean up any cache left over from a previous version of this
  // service worker, so an old cached shell never lingers forever.
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== SHELL_CACHE_NAME).map((key) => caches.delete(key)))
    )
  )
})

self.addEventListener("fetch", (event) => {
  // Only ever intercept simple page navigations -- everything else
  // (the live map's API calls, the websocket connection, map tiles)
  // passes straight through to the real network untouched.
  if (event.request.mode !== "navigate") return

  event.respondWith(
    fetch(event.request).catch(() => caches.match("/"))
  )
})
