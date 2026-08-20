# The plain landing page anyone can see -- explains what the app is,
# offers a "type in a join code" box for someone who got a code read
# out loud rather than a clickable link, and points organizers at
# sign-in. No location data, no map, nothing sensitive here.
class HomeController < ApplicationController
  # Public: the whole point of a landing page is that it works before
  # anyone's proven who they are.
  allow_unauthenticated_access

  def index
  end

  # Handles the "I have a join code" box on the home page -- looks the
  # slug up and, if it's real, sends the visitor on to that event's
  # join screen exactly as if they'd clicked a real link.
  def find_event
    event = Event.find_by(slug: params[:slug].to_s.strip)
    if event
      redirect_to event_map_path(event)
    else
      redirect_to root_path, alert: "That code doesn't match any event. Double-check it and try again."
    end
  end
end
