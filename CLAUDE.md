# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`ocpp-rails` is a **mountable Rails engine** (`isolate_namespace Ocpp::Rails`, `api_only`) that implements an OCPP 1.6 **Central System / CSMS** — the server side that EV charge points connect *to*. It is **backend-only**: it owns the WebSocket transport, the OCPP message layer, the data models, and outbound-command jobs. The consuming application builds its own UI, auth, and business logic on top. There is no view layer here by design.

Compliance is measured against the Open Charge Alliance **OCTT** Central-System test cases (76 total; 32 implemented + tested). The README's compliance table is deliberately, precisely honest — a past commit removed inflated claims. **Do not overstate coverage**; when you implement a case, move it in `docs/octt-test-plan.md` and add a real test (see Testing below).

## Commands

```bash
bin/rails test                              # full suite (~319 tests)
bin/rails test test/ocpp/                   # just the OCPP handler/job tests
bin/rails test test/ocpp/message_handler_test.rb          # single file
bin/rails test test/ocpp/message_handler_test.rb:42       # single file, by line
ruby -Itest test/ocpp/message_handler_test.rb             # single file, no Rails boot

bin/rubocop                                 # lint (rubocop-rails-omakase style)
bin/rubocop -a                              # autofix

gem build ocpp-rails.gemspec                # package (must build with zero warnings)
bin/rails ocpp:authorizations:cleanup       # prune old Authorization rows
bin/rails ocpp:state_changes:cleanup        # prune old StateChange rows
```

**Testing gotcha:** the suite runs against **one shared SQLite DB** (`test/dummy/storage/test.sqlite3`), single-process and transactional (no `parallelize`), with a 5s busy-timeout. Running multiple test processes at once (e.g. parallel subagents) throws transient `SQLite3::BusyException: database is locked` — just re-run. A harmless `rails/tasks/statistics.rake` deprecation warning prints on every run; ignore it.

Toolchain (kept mutually compatible): **Ruby 4.x** (`.ruby-version` = 4.0.5, gemspec floor `>= 4.0`), **Rails 8.1.3**, **minitest 6.0.6**, **rubocop 1.88.1**. `test/dummy/` is the host app the engine's tests boot against.

## Message-flow architecture (the core)

Everything routes through one WebSocket channel and one dispatcher. Read these three files together to understand the whole system: `app/channels/ocpp/rails/charge_point_channel.rb`, `app/services/ocpp/rails/message_handler.rb`, `app/services/ocpp/rails/protocol.rb`.

1. **Connect** — a charge point opens a WebSocket to ActionCable and subscribes to `ChargePointChannel` with its `charge_point_id`. `#subscribed` runs, in order: connection rate-limit → `StationAuthenticator.authenticate` (HTTP Basic Auth on the upgrade = OCPP-J Security Profile 1, default on) → `stream_for @charge_point` → mark connected + log a `StateChange`.
2. **Inbound frame** — `ChargePointChannel#receive` applies a per-station message rate limit (drops *before* any DB write), then hands the raw string to `MessageHandler.new(charge_point, raw).process`.
3. **Parse + route** — `Protocol.parse` decodes the OCPP-J array wire format (`[MessageTypeId, uniqueId, action, payload]`) into CALL / CALLRESULT / CALLERROR. `MessageHandler` then:
   - **CALL** → `constantize`s `Ocpp::Rails::Actions::#{action}Handler`, builds it with `(charge_point, message_id, payload)`, calls `#call`, wraps the returned hash in a CALLRESULT via `Protocol.build_callresult`, and sends it with `ChargePointChannel.broadcast_to`. Unknown action → CALLERROR `NotSupported`.
   - **CALLRESULT / CALLERROR** → correlates by `message_id` with the *pending outbound* `Message` row and updates its status. This is how outbound commands (below) get their reply.
   - Any exception → a generic CALLERROR carrying an `errorRef` correlation id; the real exception is logged server-side only. **Never leak internal exception detail to the station.**
4. **Audit** — every frame in *and* out is persisted as a `Message` row.

### Two directions = two extension patterns

Adding OCPP support almost always means one of these:

- **Inbound (station → CS): add a handler.** Create `app/services/ocpp/rails/actions/<Action>Handler.rb` — a plain object with `#call` returning the response payload hash. `MessageHandler` discovers it purely by the `Ocpp::Rails::Actions::#{action}Handler` naming convention; there is no registry to update. See `boot_notification_handler.rb` for the shape.
- **Outbound (CS → station): add a job.** Create `app/jobs/ocpp/rails/<Operation>Job.rb` — an ActiveJob that builds a CALL with `Protocol.build_call`, writes a **pending** outbound `Message` row, and delivers it via `ChargePointChannel.broadcast_to`. The station's later CALLRESULT closes the loop through `MessageHandler#handle_callresult`. See `reset_job.rb` for the canonical shape. Consumers trigger these with `perform_later`.

## Models & extension points

Models live in `app/models/ocpp/rails/` (all tables prefixed `ocpp_`): `ChargePoint`, `ChargingSession`, `MeterValue`, `Message` (the audit log), `Authorization`, `StateChange`. Note `transaction_id` is a dedicated random 31-bit integer, **not** the AR primary key — outbound stop/meter operations resolve sessions by it.

Behavior is customized through `Ocpp::Rails.setup { |config| ... }` (`lib/ocpp/rails.rb`, `Configuration`):
- `authentication_mode` — `:basic` (default) or `:none`.
- **Authorization hooks** (`register_authorization_hook`) — plug in real RFID/idTag validation; orchestrated by `AuthorizationHookManager`, run async via `AuthorizationAsyncHookJob`.
- **State-change hooks** (`register_state_change_hook`) — react to connector/connection transitions; `StateChangeHookManager` + `AsyncHookJob`.
- Rate limits, retention/cleanup windows, and `implausible_energy_jump_wh` (used by `MeterAnomalyDetector`; unparseable station clocks are handled by `TimestampParser`, which flags rather than silently substitutes server time).

Consumers install with `rails generate ocpp:rails:install` (copies migrations + initializer, mounts the engine).

## Testing philosophy (matters for compliance claims)

The suite has two distinct kinds of tests, and the distinction is load-bearing:
- **Handler/job-driven tests** push real frames through `MessageHandler` / `Actions::*Handler` / jobs and assert on actual behavior. **Only these count toward OCTT coverage.**
- **Simulation-style tests** (older files under `test/ocpp/integration/`) build request/response hashes and rows by hand *without* invoking production code. They document message shapes but prove nothing about wire compliance and are **not** counted.

When implementing a 🔴/🟡 case from `docs/octt-test-plan.md`, add a **handler/job-driven** test for it.

## Releasing

Publishing to RubyGems is automated via GitHub Actions **trusted publishing** (OIDC, no stored secrets), triggered by pushing a `v*` tag. Full process and one-time setup are in [RELEASING.md](RELEASING.md). Bump `lib/ocpp/rails/version.rb` and add a dated `CHANGELOG.md` entry before tagging.
