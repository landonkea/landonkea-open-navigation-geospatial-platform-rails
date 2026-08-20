# This is the live wire the map page listens on. When someone's phone
# posts a fresh position (see PositionsController#create), we push
# that update out over this channel to every browser currently
# watching the same event, so everyone's dot moves in real time
# without anyone hitting refresh. This is what replaces the original
# app's polling loop and Supabase Realtime with Rails' own Action
# Cable, backed by Solid Cable so it needs no extra infrastructure
# (see config/cable.yml).
#
# Deliberately a plain data channel, not a Turbo Stream broadcast: a
# map marker lives on a WebGL canvas MapLibre draws, not as real DOM
# elements Turbo could replace, so the browser-side JavaScript needs
# the raw lat/lng/status data itself to move the marker (see
# app/javascript/controllers/live_map_controller.js). The event
# roster list, by contrast, IS plain DOM, so that uses a Turbo Stream
# broadcast instead -- see Participant#broadcast_roster_update.
class EventChannel < ApplicationCable::Channel
  # Called once when a browser's JavaScript subscribes to this
  # channel for a specific event (see live_map_controller.js's
  # `createConsumer().subscriptions.create`).
  def subscribed
    event = Event.find_by(slug: params[:event_slug])
    # No such event, or a bad/mistyped slug snuck through somehow --
    # refuse the subscription outright rather than silently streaming
    # nothing forever.
    return reject unless event

    # stream_for gives this event its own private broadcast address
    # (something like "event_channel:Event:42"), so a browser watching
    # event A never receives updates meant for event B.
    stream_for event
  end
end
