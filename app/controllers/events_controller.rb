# Organizer-side event management: creating an event, starting it so
# people can join, ending it, and watching who's shown up. Everything
# in here requires a signed-in organizer -- there's no
# allow_unauthenticated_access call anywhere in this file, so
# ApplicationController's default require_authentication (from Rails
# 8's own authentication generator) applies to every action.
#
# ANY organizer can manage ANY event here, not just ones they
# personally created -- matches the original app's own "any admin can
# edit/end any ride" design, deliberate shared access so a small,
# trusted group isn't bottlenecked on one person.
class EventsController < ApplicationController
  before_action :set_event, only: %i[show start finish]

  def index
    @events = Event.order(created_at: :desc)
  end

  def new
    @event = Event.new
  end

  def create
    # Current.user comes from Rails' own authentication system --
    # whichever organizer is signed in right now becomes this event's
    # creator, exactly like the original app's created_by column.
    @event = Current.user.events.build(event_params)
    if @event.save
      redirect_to @event, notice: "Event created. It's not live yet -- start it when you're ready for people to join."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @participants = @event.participants.order(created_at: :desc)
  end

  def start
    @event.start!
    redirect_to @event, notice: "Event is live. Share its join link and people can start joining."
  end

  def finish
    @event.end!
    redirect_to @event, notice: "Event ended."
  end

  private

  # Rails passes the URL's slug segment in params[:id] here (the route
  # is a plain `resources :events`), even though it's really a slug,
  # not a numeric id -- that's just what the standard resourceful route
  # calls its identifying param, we look it up by slug regardless
  # since Event#to_param made slug what actually appears in the URL.
  def set_event
    @event = Event.find_by!(slug: params[:id])
  end

  # Only :name is ever accepted from the form -- status/slug/started_at
  # are all managed by the model itself (see Event#start!, Event#end!,
  # and the slug-generating before_validation), never set directly from
  # user input.
  def event_params
    params.require(:event).permit(:name)
  end
end
