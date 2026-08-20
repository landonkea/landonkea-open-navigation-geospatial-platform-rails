# Recognizes a returning participant across page loads without ever
# asking them to log in. This is the public-facing counterpart to the
# organizer login system Rails 8's authentication generator built (see
# app/controllers/concerns/authentication.rb) -- same underlying idea
# (a signed, tamper-proof cookie naming a database row), just for
# someone who never created an account.
#
# WHY A COOKIE, NOT LOCALSTORAGE (the original app's approach): the
# original TypeScript app generated a random id in the browser's
# localStorage and just trusted whatever id showed up on each request,
# its own schema comment admits this openly. A signed Rails cookie
# does better for free: the browser can't edit or forge it (it's
# cryptographically signed with this app's secret key, see
# config/credentials.yml.enc), so "this cookie names participant #42"
# is a real, verifiable fact, not a polite convention.
module ParticipantIdentity
  extend ActiveSupport::Concern

  private

  # One cookie slot per event (not one shared across every event a
  # visitor ever joins), matching the original design's same per-event
  # isolation -- joining event A shouldn't say anything about whether
  # you're also in event B.
  def participant_cookie_name(event)
    "participant_id_#{event.id}"
  end

  # Looks up the participant this browser has already proven it owns
  # for @event, or nil for a brand-new visitor. Memoized with
  # defined?/@current_participant so repeated calls in the same
  # request don't re-query the database.
  def current_participant
    return @current_participant if defined?(@current_participant)

    stored_id = cookies.signed[participant_cookie_name(@event)]
    @current_participant = stored_id ? @event.participants.find_by(id: stored_id) : nil
  end

  # Stamps this browser as owning the given participant row, good for
  # a year so reopening the join link later still recognizes them
  # (the same "stays remembered" behavior the original's localStorage
  # id gave). httponly stops any injected JavaScript from reading it;
  # same_site: :lax still lets it ride along when someone opens the
  # join link fresh (e.g. from a text message).
  def remember_participant(participant)
    cookies.signed.permanent[participant_cookie_name(participant.event)] = {
      value: participant.id,
      httponly: true,
      same_site: :lax
    }
  end

  def forget_participant(event)
    cookies.delete(participant_cookie_name(event))
  end
end
