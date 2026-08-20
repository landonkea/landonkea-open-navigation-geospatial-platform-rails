# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_20_152551) do
  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "started_at"
    t.string "status", default: "created", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["slug"], name: "index_events_on_slug", unique: true
    t.index ["user_id"], name: "index_events_on_user_id"
    t.check_constraint "status IN ('created', 'active', 'ended')", name: "events_status_check"
  end

  create_table "participants", force: :cascade do |t|
    t.float "accuracy_m"
    t.string "color"
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.float "heading_deg"
    t.boolean "is_spectator", default: false, null: false
    t.datetime "last_moved_at"
    t.datetime "last_seen_at"
    t.float "lat"
    t.float "lng"
    t.float "speed_mps"
    t.string "tag"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_participants_on_event_id"
  end

  create_table "positions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.float "lat", null: false
    t.float "lng", null: false
    t.integer "participant_id", null: false
    t.datetime "recorded_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_positions_on_event_id"
    t.index ["participant_id"], name: "index_positions_on_participant_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "events", "users"
  add_foreign_key "participants", "events"
  add_foreign_key "positions", "events"
  add_foreign_key "positions", "participants"
  add_foreign_key "sessions", "users"
end
