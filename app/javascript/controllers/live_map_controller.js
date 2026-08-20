// This is the one piece of real client-side logic in the whole app:
// it draws the live map, keeps it updated in real time as other
// people's positions change, and (if this browser is a rider, not a
// spectator) reads this device's own GPS and reports it back to the
// server on a timer. Everything else in the app is plain
// server-rendered HTML; this page needs actual JavaScript because a
// map marker lives on a canvas MapLibre draws, not as normal HTML
// elements Turbo could update on its own.

import { Controller } from "@hotwired/stimulus"
// MapLibre's own module only exports named exports, no default export
// bundling everything together (unlike some older versions/libraries),
// so each piece gets pulled in by name here. MapLibreMap is renamed on
// the way in since "Map" would otherwise collide with the browser's
// own built-in Map class, used just below for markersByParticipantId.
import { Map as MapLibreMap, Marker, NavigationControl, LngLatBounds } from "maplibre-gl"
import consumer from "channels/consumer"

// How often (in milliseconds) a rider's browser asks the device for a
// fresh GPS reading and reports it to the server. Matches the
// original app's own default polling interval.
const CHECK_IN_INTERVAL_MS = 10_000

// The free, no-signup map tile style this app uses -- see the
// original project's src/core/map.ts for why (no per-load billing,
// which matters once a lot of people open the map at the same time).
const MAP_STYLE_URL = "https://tiles.openfreemap.org/styles/liberty"

// The colors a participant's dot can show, matching the same
// green/yellow/red meaning GeoMath.signal_status uses server-side.
const STATUS_COLORS = { green: "#2e7d32", yellow: "#f9a825", red: "#c62828" }

export default class extends Controller {
  static targets = ["map", "status"]

  static values = {
    eventSlug: String,
    participantId: Number,
    isSpectator: Boolean,
    positionsUrl: String,
    // Every current participant's position, rendered server-side into
    // this page already -- lets the map show everyone immediately on
    // load instead of waiting for the first live update to arrive.
    initialParticipants: Array
  }

  connect() {
    // Wrapped in try/catch on purpose: without this, a single failure
    // anywhere in setup (a network hiccup loading map tiles, a
    // browser that blocks something) leaves someone staring at
    // "Connecting..." forever with no clue why. This turns that into
    // an actual, visible message instead of a silent dead end.
    try {
      this.setUpMap()
    } catch (error) {
      console.error("Live map failed to start:", error)
      this.statusTarget.textContent = `Couldn't load the live map (${error.message}). Try reloading the page.`
    }
  }

  setUpMap() {
    // One MapLibre.Marker instance per participant, keyed by their
    // database id, so a later update can move the SAME marker instead
    // of drawing a new one on top of it every time.
    this.markersByParticipantId = new Map()

    this.map = new MapLibreMap({
      container: this.mapTarget,
      style: MAP_STYLE_URL,
      center: [-111.8315, 33.4152], // a reasonable default (Mesa, AZ, the original app's pilot city) until real positions arrive
      zoom: 11
    })
    this.map.addControl(new NavigationControl(), "bottom-right")

    // Draw whatever positions the page already knows about, then
    // subscribe for live updates on top of that starting point.
    this.initialParticipantsValue.forEach((participant) => this.upsertMarker(participant))
    this.fitMapToMarkersIfAny()

    this.subscribeToLiveUpdates()

    if (!this.isSpectatorValue) {
      this.startReportingOwnPosition()
    } else {
      this.statusTarget.textContent = "Watching live -- your own location is never requested."
    }
  }

  // Runs when this controller's element leaves the page (navigating
  // away, an explicit "Leave" click, etc.) -- without this, the
  // geolocation timer and the websocket subscription would both keep
  // running invisibly in the background forever.
  disconnect() {
    if (this.checkInTimer) clearInterval(this.checkInTimer)
    if (this.subscription) this.subscription.unsubscribe()
    if (this.map) this.map.remove()
  }

  // Opens (or reuses) the shared Action Cable connection and listens
  // for this one event's channel -- see app/channels/event_channel.rb
  // for the server side of this exact same subscription.
  subscribeToLiveUpdates() {
    this.subscription = consumer.subscriptions.create(
      { channel: "EventChannel", event_slug: this.eventSlugValue },
      {
        connected: () => {
          this.statusTarget.textContent = this.isSpectatorValue
            ? "Watching live -- your own location is never requested."
            : "Live -- your location is sharing."
        },
        disconnected: () => {
          this.statusTarget.textContent = "Disconnected -- trying to reconnect..."
        },
        received: (participant) => this.upsertMarker(participant)
      }
    )
  }

  // Creates a participant's marker the first time we hear about them,
  // or moves/recolors their existing one on every later update --
  // this one method covers both cases so callers don't need to check
  // which situation they're in.
  upsertMarker(participant) {
    // A spectator has no position to plot at all -- nothing to draw.
    if (participant.is_spectator || participant.lat == null || participant.lng == null) return

    const existing = this.markersByParticipantId.get(participant.id)
    if (existing) {
      existing.setLngLat([participant.lng, participant.lat])
      existing.getElement().style.backgroundColor = this.colorForParticipant(participant)
      return
    }

    const element = document.createElement("div")
    element.style.width = "16px"
    element.style.height = "16px"
    element.style.borderRadius = "50%"
    element.style.border = "2px solid white"
    element.style.boxShadow = "0 0 2px rgba(0,0,0,0.5)"
    element.style.backgroundColor = this.colorForParticipant(participant)

    const marker = new Marker({ element })
      .setLngLat([participant.lng, participant.lat])
      .addTo(this.map)

    this.markersByParticipantId.set(participant.id, marker)
  }

  // A rider's own chosen color takes priority (purely cosmetic, helps
  // people spot themselves/a friend at a glance); everyone else falls
  // back to the same green/yellow/red signal-status color the roster
  // list uses.
  colorForParticipant(participant) {
    return participant.color || STATUS_COLORS[participant.status] || "#ff7e1f"
  }

  // Zooms/pans the map to frame every marker currently on it, so a
  // rider joining an event already in progress doesn't land on a
  // default view with nobody visible. Only runs once, at startup --
  // later updates just move markers in place, refitting the view on
  // every single update would be disorienting to actually use.
  fitMapToMarkersIfAny() {
    if (this.markersByParticipantId.size === 0) return

    const bounds = new LngLatBounds()
    this.markersByParticipantId.forEach((marker) => bounds.extend(marker.getLngLat()))
    this.map.fitBounds(bounds, { padding: 60, maxZoom: 15, duration: 0 })
  }

  // Starts the repeating "ask the device for a GPS fix, tell the
  // server" loop for a rider. Fires once immediately (so a rider
  // doesn't wait a full interval to first appear), then again every
  // CHECK_IN_INTERVAL_MS.
  startReportingOwnPosition() {
    this.reportOwnPosition()
    this.checkInTimer = setInterval(() => this.reportOwnPosition(), CHECK_IN_INTERVAL_MS)
  }

  reportOwnPosition() {
    if (!("geolocation" in navigator)) {
      this.statusTarget.textContent = "This browser can't share your location."
      return
    }

    navigator.geolocation.getCurrentPosition(
      (position) => this.sendPositionToServer(position),
      (error) => {
        // A single missed reading isn't worth alarming anyone over --
        // log it and let the next timer tick try again.
        console.warn("Location read failed, will retry:", error.message)
      },
      { enableHighAccuracy: true, timeout: 8_000 }
    )
  }

  async sendPositionToServer(position) {
    const body = new URLSearchParams({
      lat: position.coords.latitude,
      lng: position.coords.longitude,
      accuracy_m: position.coords.accuracy ?? "",
      // Not every device/browser reports heading and speed (they're
      // only available from a real moving GPS fix, not a stationary
      // or network-based one) -- send an empty string rather than the
      // literal word "null" when they're missing.
      heading_deg: position.coords.heading ?? "",
      speed_mps: position.coords.speed ?? ""
    })

    const response = await fetch(this.positionsUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        // Rails rejects a POST with no valid CSRF token by default --
        // this reads the token the layout already embeds in a <meta>
        // tag (see csrf_meta_tags in app/views/layouts/application.html.erb).
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        Accept: "application/json"
      },
      body
    })

    if (response.status === 410) {
      // The server says this event has ended -- stop trying to share,
      // and let the person know why their dot stopped updating.
      clearInterval(this.checkInTimer)
      this.statusTarget.textContent = "This event has ended. Thanks for sharing your location."
      return
    }

    if (!response.ok) {
      console.warn("Position update failed:", response.status)
    }
  }
}
