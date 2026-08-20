# Open Navigation & Geospatial Platform (Rails rewrite)

A web app that shows a group's live location on one shared map during an event — a group ride, a hike, a scavenger hunt, an indoor kiosk. An organizer starts an event and shares one link. Anyone with that link can watch the live map instantly, no account needed, and can choose to share their own position too.

**This is an independent, educational rewrite. It is not connected to any live production service.** The original project this was rebuilt from — [`landonkea-open-navigation-geospatial-platform`](https://github.com/landonkea/landonkea-open-navigation-geospatial-platform) — is a real, currently-deployed app with a real Supabase backend and real users tracking their own group rides. This repository is a from-scratch Rails rewrite in a completely separate codebase: it has no access to that project's credentials, doesn't talk to its database, and holds no real location data from anyone. Running this code creates a brand-new, empty app on your own machine (or your own server, if you deploy it) — it is not a way to view or affect the original service. Don't rely on this rewrite for actual group safety or location tracking unless you deliberately deploy and configure a copy of it yourself and understand what you're running.

## What's actually in this app

Four kinds of "thing" the database knows about:

- **Users** — organizers. The only people who ever log in. An organizer creates events, starts them, and ends them.
- **Events** — one event is one ride/hike/session. Every event has a short join code (like `08202026`) that doubles as its join link — anyone who has that code can open the event's map.
- **Participants** — everyone who joins an event, whether they're actively sharing their location ("riders," in the code) or just watching ("spectators"). Participants never create accounts. The first time someone joins, the app hands their browser a signed cookie that says "you are participant #42 in this event" — the browser can't forge or edit that cookie, so on every later visit the app recognizes the same person without a password.
- **Positions** — a permanent trail of where each participant has been. Separate from a participant's *current* position (which just gets overwritten every time their phone checks in): this table gets a brand-new row every so often, building up a full route over the length of an event.

## How the "live" part actually works

This is the part most worth understanding if you're new to this:

1. A rider's phone reads its own GPS position every 10 seconds (using the browser's built-in Geolocation API) and sends it to the Rails server as a normal web request.
2. The server saves that position, then announces it over a live connection called Action Cable — think of it as a phone line that stays open between the server and every browser currently looking at that event's map, instead of everyone having to keep asking "anything new?" over and over.
3. Every other browser watching that same event is listening on that same line. The instant the server announces an update, their JavaScript moves that rider's dot on the map — no page refresh, no polling.
4. Rails' *Solid Cable* is what makes that live connection work without needing any extra piece of infrastructure (like Redis) installed — it uses the same SQLite database the rest of the app already has.

There's a second live mechanism doing something similar for the plain "who's here" list on the page: that one uses *Turbo Streams*, a Rails feature that re-renders a chunk of HTML on the server and pushes the finished HTML out to every connected browser, replacing that one spot on the page. It's a different tool from the map marker updates because a map marker is drawn on a canvas (by the MapLibre map library), not as regular HTML — Turbo can swap HTML elements, but it can't reach inside a canvas, so the map gets its own smaller, JavaScript-driven channel instead.

## How this differs from the original app (and why)

The original TypeScript app talked to Supabase (a hosted Postgres + login service) over plain repeated HTTP requests on a timer ("polling"), specifically because Supabase's free tier caps how many people can hold a live connection open at once. This rewrite uses genuine push-based updates over Action Cable instead, because that's what the brief asked for and because Solid Cable removes the "how many live connections can we afford" problem entirely — it's backed by your own database, not a shared external service with a connection limit.

The original let anyone update any participant's row, trusting a random id generated in the browser's own storage, and says so plainly in its own schema comments as an accepted tradeoff for a no-login app. This rewrite does better on that specific point for free, just by being Rails: the signed cookie described above means the server can actually verify a request is coming from the browser that owns that participant row, not merely trust whatever id shows up.

A few original features didn't make it into this rewrite, to keep the scope realistic for a from-scratch build: GPX route upload/drawing, satellite map view, map marker clustering at scale, rider tags/colors picked from a themed picker, ride highlights/feedback, and CSV/GPX export. The core loop — join, share location, watch everyone move live, organizer starts/ends the event — is fully real and working, not a stub.

## Running this yourself

You'll need Ruby (this app was built against 3.4.9) and no separate database server — it uses SQLite, which ships as a file alongside the app.

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

Then open `http://localhost:3000`. To try the organizer side, sign in requires an account — create one from a Rails console the first time:

```bash
bin/rails console
User.create!(email_address: "you@example.com", password: "a-real-password")
```

### Environment variables

Check `.env.example` — as of this build, the app doesn't need any secrets to run locally (the map tiles are free and keyless). That file is there as the obvious place to add a real one later, and explains where Rails' own `config/master.key` fits in (it's not an environment variable, and it's deliberately never committed to git).

### Running the tests

```bash
bin/rails db:test:prepare
bin/rails test           # models, controllers, the auth flow
bin/rails test:system    # a real headless-Chrome test proving a position update reaches another open browser tab live
```

The system test needs a real Chrome/Chromium install on your machine; everything else needs nothing beyond what `bundle install` already sets up.

### Running it in Docker

```bash
docker build -t open-nav-rails .
docker run -d -p 3000:80 -e RAILS_MASTER_KEY=$(cat config/master.key) open-nav-rails
```

## File-by-file, in plain English

- `app/models/event.rb`, `participant.rb`, `position.rb`, `user.rb` — the four things described above, plus `geo_math.rb` (GPS distance/movement math, kept separate so it's easy to test on its own) and `policy.rb` (tunable numbers like "how often to log a trail point").
- `app/controllers/events_controller.rb` — organizer-only: create an event, start it, end it, see who's joined.
- `app/controllers/maps_controller.rb` and `positions_controller.rb` — the public side: opening a join link, choosing rider vs. spectator, and posting a fresh GPS reading.
- `app/controllers/concerns/participant_identity.rb` — the signed-cookie trick described above, explained in detail in its own comments.
- `app/channels/event_channel.rb` — the live wire map updates travel over.
- `app/javascript/controllers/live_map_controller.js` — the one substantial piece of hand-written JavaScript in the app: draws the map, listens for live updates, and (for a rider) reports this device's own position on a timer.
- `test/` — Minitest coverage for the models, the join/position/auth flows, the channel in isolation, and one real browser-driven system test.

## License

MIT, matching the original project's own choice — see `LICENSE`.
