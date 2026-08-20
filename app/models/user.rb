class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  # The generator that scaffolded this file added a unique INDEX on
  # email_address at the database level (see the CreateUsers
  # migration) but no matching Ruby-level validation, so a duplicate
  # signup would only surface as a raw, ugly ActiveRecord::RecordNotUnique
  # exception instead of a normal, friendly form error. Added by hand.
  validates :email_address, presence: true, uniqueness: true

  # A User here is always an organizer -- the small group of people
  # trusted to create and run events, the rest of this app's visitors
  # never get an account at all (see app/models/participant.rb for
  # how everyone else is identified). dependent: :destroy protects
  # against ever having an orphaned event with no real organizer.
  has_many :events, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
