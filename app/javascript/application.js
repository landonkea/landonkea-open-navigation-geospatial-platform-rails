// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Registers the service worker at app/views/pwa/service-worker.js so
// the app can actually be installed to a phone's home screen, same as
// the original PWA. Guarded by the feature check since older browsers
// (and some in-app webviews) don't support service workers at all.
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker").catch((error) => {
      console.warn("Service worker registration failed:", error)
    })
  })
}
