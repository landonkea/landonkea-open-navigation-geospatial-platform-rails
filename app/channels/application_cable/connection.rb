module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    # The scaffolded version of this file rejected any connection that
    # wasn't a signed-in organizer -- fine for an admin-only app, but
    # this app's live map is watched by regular participants who never
    # log in at all (see app/models/participant.rb). Reject-if-no-user
    # would mean nobody could ever open the live map's websocket
    # connection, so we set current_user when there IS an organizer
    # session (still useful, e.g. for a future admin-only channel) but
    # otherwise just let the connection through as anonymous. Positions
    # channel itself decides what an anonymous connection is allowed to
    # stream, see app/channels/event_channel.rb.
    def connect
      set_current_user
    end

    private
      def set_current_user
        if session = Session.find_by(id: cookies.signed[:session_id])
          self.current_user = session.user
        end
      end
  end
end
