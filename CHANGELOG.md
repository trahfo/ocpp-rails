# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Native raw OCPP-J transport.** Real charge points speak bare OCPP-J over a plain WebSocket (subprotocol `ocpp1.6`, identity in the URL path, frames are bare `[2,"id","Action",{…}]` arrays); the existing endpoint only accepted the ActionCable-wrapped protocol, so a stock station could not connect. Set `config.transport = :raw` and stations connect directly at `ws://host/ocpp/<identifier>`. `Ocpp::Rails::RawSocket::Endpoint` is a Rack app (mounted by the engine when the transport is enabled) that authenticates from the upgrade request with the existing `StationAuthenticator` (Security Profile 1) and connection rate limiter, then bridges the socket to the same transport-agnostic core (`MessageHandler`, handlers, hooks, audit) the ActionCable channel uses. Outbound frames (CALLRESULTs and remote-control CALLs) ride the existing `ChargePointChannel` broadcasting, so cross-process delivery (a job on a different worker than the socket) works through the configured pub/sub adapter with no producer changes.
- `config.transport` (`:action_cable` (default) | `:raw` | `:both`), plus `config.raw_socket_path`, `config.websocket_subprotocols`, and `config.raw_socket_max_frame_bytes`.

### Changed
- No behavioural change to the default `:action_cable` transport — existing deployments are unaffected.

## [0.3.0] - 2026-07-12

### Added
- **Per-connector status tracking.** `Ocpp::Rails::ConnectorStatus` (table `ocpp_connector_statuses`) is a first-class model holding the last status/error code a station reported per connector, replacing the old `metadata["connector_<n>_status"]` convention. Read it via `ChargePoint#connector_status(connector_id)` / `#connector_error_code(connector_id)`. `ChargePoint#connector_charging?(connector_id)` derives a session-based "is this connector transacting right now" signal, independent of StatusNotification timing.
- **Session lifecycle hooks.** `config.register_session_hook(hook)` registers an object responding to `call(charging_session, event)` (`event` is `"started"` or `"stopped"`), fired from `StartTransactionHandler`/`StopTransactionHandler` — no more polling `ChargingSession.active`. Hooks with `async? => true` run via the new `SessionAsyncHookJob`, mirroring the existing authorization/state-change hook pattern. `"stopped"` fires after `transactionData` meter values are persisted, so a hook can read final energy/CDR data immediately. Duplicate/replayed `StartTransaction`s that resume an already-open session intentionally do not re-fire `"started"`.
- `bin/rails generate ocpp:rails:install` now also copies the `ocpp_connector_statuses` migration and documents `session_hooks` in the generated initializer.

### Changed
- **Breaking:** `StartTransactionHandler`/`StopTransactionHandler` no longer write `ChargePoint#status`. Per OCPP 1.6, connector 0's status has no direct connection to any individual connector's status — whole-station `status` is now driven exclusively by connector-0 `StatusNotification`s (plus `BootNotification`/`Heartbeat` connectivity). This fixes a real bug on multi-connector stations: starting or stopping a transaction on one connector no longer flips the whole station's status, stomping on a sibling connector's state.
- **Breaking:** `ChargePoint.charging` scope is now session-derived (`ChargePoint`s with at least one active `ChargingSession`, any connector) instead of matching on `status == "Charging"`, since `status` no longer takes that value from the transaction lifecycle.
- A migration backfills existing `metadata["connector_<n>_status"/"_error_code"]` keys into `ocpp_connector_statuses` and removes them from `metadata`. Any rows already written by the new StatusNotification path (i.e. on a station that already reported since upgrading) win over the legacy metadata.

### Upgrade notes
- Run `bin/rails ocpp_rails:install:migrations && bin/rails db:migrate` to add `ocpp_connector_statuses` and backfill it from `metadata`.
- If you read `charge_point.metadata["connector_<n>_status"]` or relied on `ChargePoint.charging`/`status` reflecting an in-progress transaction, switch to `connector_status`/`connector_charging?`.

## [0.2.4] - 2026-07-08

### Fixed
- The `v0.2.3` tag was cut before the RubyGems trusted-publishing workflow
  (`.github/workflows/push_gem.yml`) was added, so pushing it could never
  trigger a publish — GitHub Actions resolves workflow files from the exact
  commit a tag points to, not from `main`. `v0.2.3` is retired unused (the gem
  was never actually published under it); `v0.2.4` is the real first release.

## [0.2.3] - 2026-07-08

### Added
- **First public release on [RubyGems.org](https://rubygems.org/gems/ocpp-rails).** Install with `gem install ocpp-rails` or add `gem "ocpp-rails"` to your Gemfile — no more Git-source dependency required.
- Automated publishing via GitHub Actions [trusted publishing](https://guides.rubygems.org/trusted-publishing/) (OIDC): pushing a `v*` tag builds and pushes the gem to RubyGems with no stored API keys. See [RELEASING.md](RELEASING.md).

### Changed
- Gemspec now declares `required_ruby_version >= 4.0`, distinct `source_code_uri` / `changelog_uri` / `bug_tracker_uri` / `documentation_uri` metadata, and `rubygems_mfa_required`, clearing all `gem build` warnings.

## [0.2.2] - 2026-07-08

### Added
- **GetConfiguration** outbound operation (`GetConfigurationJob`) — retrieve all keys (empty/omitted key list) or specific keys (OCTT TC_019_1 / TC_019_2).
- **ChangeConfiguration** outbound operation (`ChangeConfigurationJob`) — set a key/value; Accepted, NotSupported, and Rejected confirmations are all recorded without error (OCTT TC_021 / TC_040_1 / TC_040_2).
- **ChangeAvailability** outbound operation (`ChangeAvailabilityJob`) — Operative/Inoperative for a single connector or the whole charge point (connectorId 0); Accepted/Scheduled confirmations recorded. Completes the `ChangeAvailability` dependency noted in TC_048_3.
- Handler/job-driven tests for all three, raising OCTT Central-System coverage to **32 of 76** cases — the full Core outbound command set is now implemented.

## [0.2.1] - 2026-07-07

### Added
- **Reset** outbound operation (`ResetJob`) — Hard and Soft resets (OCTT TC_013 / TC_014); the station re-registers through the existing BootNotification/StatusNotification handlers afterward.
- **ClearCache** outbound operation (`ClearCacheJob`) — clears the charge point's authorization cache (OCTT TC_061).
- Handler/job-driven tests for Reset and ClearCache, raising OCTT Central-System coverage to **27 of 76** cases.

## [0.2.0] - 2026-07-07

### Added
- **UnlockConnector** outbound operation (`UnlockConnectorJob`) — releases a connector, including during an active charging session (OCTT TC_017_1/TC_017_2/TC_018_1).
- **OCTT Core-profile regression suite** — real handler/job-driven tests now guard **24 of 76** OCTT Central-System cases; the "implemented but untested" backlog is cleared. Covers cold boot, Authorize non-happy paths (Invalid/Expired/Blocked), StatusNotification (incl. ConnectorLockFailure/Faulted), EV-side disconnect, cached-id start, remote start/stop end-to-end and rejection, offline + power-loss replay, and the post-connect boot sequence. See `docs/octt-test-plan.md` for the per-case breakdown.

### Changed
- Upgraded Rails to **8.1.3**, minitest to **6.0.6**, and rubocop to **1.88.1** (mutually compatible on Ruby 4.0); removed the temporary `minitest ~> 5.25` pin now that Rails 8.1 realigned its test line-filtering with minitest 6's `Runnable#run`.

### Security
- **Charge points now authenticate** (OCPP-J Security Profile 1, HTTP Basic Auth on the WebSocket upgrade). A per-station credential is stored as a SHA-256 digest (`auth_password_digest`) and compared in constant time; unauthenticated or mismatched subscriptions are rejected before streaming and logged. **Breaking**: `authentication_mode` defaults to `:basic`; set `:none` explicitly to restore the old anonymous behaviour. See `docs/security.md`.
- CALLERROR frames no longer echo internal exception messages to the station; the peer receives a generic description plus an `errorRef` correlation id, and the full exception stays in the server log.
- Per-station ingress rate limiting: inbound messages (default 300/min) are dropped before processing or audit writes, connection attempts (default 12/min) are rejected before authentication. Both configurable, `nil` disables.

### Fixed
- Remote start/stop commands never reached the station: the jobs broadcast to a stream nothing subscribed to. They now use `ChargePointChannel.broadcast_to`, the same relay path as CALLRESULTs.
- The OCPP `transactionId` is a dedicated random 31-bit integer in `transaction_id` (unique), no longer the sequential ActiveRecord primary key; StopTransaction and MeterValues resolve sessions via that column. **Breaking**: the column changed from string (unused UUIDs) to bigint; pass `session.transaction_id` (not `session.id`) to `RemoteStopTransactionJob`.
- StartTransaction now honors the authorization hooks: a non-Accepted idTag gets the real status back and opens no session (the decision is persisted as an `Authorization` record).
- At most one active session per connector: duplicate/replayed StartTransaction resumes the open transaction, and a partial unique index enforces the invariant under races.
- Unparseable station timestamps are no longer silently replaced by server time: meter values keep the raw value and a `timestamp_source` flag, sessions are flagged in `metadata`.
- Energy register anomalies (rollover, meter swap, implausible jumps) are flagged (`flagged`/`flag_reason`, kWh normalised to Wh) instead of silently producing negative or garbage energy totals; a session stopped below `meterStart` records `nil` energy and is flagged.
- Async hook jobs retry again on Rails 8 (`wait: :polynomially_longer`; `:exponentially_longer` was removed upstream).
- The engine's ActionCable auto-configuration crashed the cable server in host apps (`adapter=` is not a valid setting); it now sets the cable hash and defers to an existing `config/cable.yml`.
- Default `supported_versions` is `["1.6"]` — the only version the gem implements; charge points can no longer be persisted with an unsupported protocol.

## [0.1.0] - YYYY-MM-DD

### Added
- **OCPP 1.6 Core Protocol Handlers**
  - BootNotification - Charge point registration and initial handshake
  - Authorize - RFID tag authorization for charging sessions
  - Heartbeat - Connection monitoring and keep-alive mechanism
  - StartTransaction - Session initiation with RFID tag
  - StopTransaction - Session completion with final meter values
  - MeterValues - Real-time energy and power readings during charging
  - StatusNotification - Connector status updates (Available, Charging, Faulted, etc.)

- **WebSocket Communication**
  - ActionCable-based bidirectional OCPP message handling
  - SQLite async adapter support (no Redis required for development)
  - Automatic connection tracking and heartbeat monitoring

- **Data Models**
  - ChargePoint - Physical charging station representation with status tracking
  - ChargingSession - Transaction management with energy/duration calculations
  - MeterValue - 22+ OCPP measurand support (Energy, Power, Current, Voltage, SoC, Temperature)
  - Message - Complete audit logging of all OCPP communications (inbound/outbound)

- **Remote Control**
  - RemoteStartTransaction - Initiate charging sessions remotely
  - RemoteStopTransaction - Terminate charging sessions remotely
  - Background job processing via ActiveJob

- **Real-Time Broadcasts**
  - ActionCable broadcasts for charge point status changes
  - ActionCable broadcasts for session updates
  - ActionCable broadcasts for meter value readings

- **Rails Integration**
  - Rails generator (`rails generate ocpp:rails:install`)
  - Database migrations for all OCPP data models
  - Initializer for configuration management
  - Engine mountable at custom path (default: `/ocpp`)

- **Developer Experience**
  - Comprehensive test suite (208 tests, 646 assertions)
  - Complete documentation with implementation guides
  - Message reference with OCPP payload examples
  - Troubleshooting guide

### Technical Details
- **Rails Version:** 7.0+ (optimized for Rails 8)
- **Ruby Version:** 3.0+
- **OCPP Compliance:** 1.6 Edition 2 Core Profile (60% complete)
- **Database Support:** PostgreSQL, MySQL, SQLite
- **WebSocket Protocol:** RFC 6455 via ActionCable

[0.2.2]: https://github.com/trahfo/ocpp-rails/releases/tag/v0.2.2
[0.2.1]: https://github.com/trahfo/ocpp-rails/releases/tag/v0.2.1
[0.2.0]: https://github.com/trahfo/ocpp-rails/releases/tag/v0.2.0
[0.1.0]: https://github.com/trahfo/ocpp-rails/releases/tag/v0.1.0
