#!/usr/bin/env bash
#
# Creates GitHub issues for ocpp-rails from the v0.3 CPMS assessment.
# Scope: OCPP 1.6 correctness/security/hardening. OCPP 2.x support intentionally EXCLUDED.
#
# Prerequisites:
#   - gh CLI installed and authenticated (gh auth status)
#   - run from anywhere; REPO is set explicitly below
#
# Usage:
#   chmod +x create-ocpp-rails-issues.sh
#   ./create-ocpp-rails-issues.sh
#
set -euo pipefail

REPO="trahfo/ocpp-rails"

# --- ensure labels exist (idempotent; ignore "already exists") -------------
ensure_label () {
  gh label create "$1" --repo "$REPO" --color "$2" --description "$3" 2>/dev/null || true
}
ensure_label "bug"           "d73a4a" "Something isn't working"
ensure_label "security"      "b60205" "Security-relevant defect"
ensure_label "correctness"   "fbca04" "Behaviour deviates from OCPP/spec"
ensure_label "hardening"     "0e8a16" "Robustness / production-readiness"
ensure_label "critical"      "b60205" "Blocks core functionality"
ensure_label "ocpp-1.6"      "1d76db" "OCPP 1.6 scope"

new_issue () {
  local title="$1"; local labels="$2"; local body="$3"
  gh issue create --repo "$REPO" --title "$title" --label "$labels" --body "$body"
}

# ===========================================================================
# CRITICAL
# ===========================================================================

new_issue \
"Remote start/stop broadcasts to a dead ActionCable stream — commands never reach the station" \
"bug,critical,ocpp-1.6" \
'## Summary
`RemoteStartTransactionJob` and `RemoteStopTransactionJob` broadcast the outbound CALL to a stream named `"charge_point_#{cp.id}_outbound"`, but the station socket (`ChargePointChannel#subscribed`) only subscribes via `stream_for @charge_point` — i.e. ActionCable'"'"'s record-derived stream name. Nothing subscribes to the `_outbound` stream, so **outbound remote-control messages are never delivered to the charge point.**

## Impact
The flagship outbound feature (advertised as "Remote Control ✅ 100%" in the README) does not function. Because the "end-to-end workflow test" only creates DB rows and asserts on them — it never routes a message through the channel — the suite does not catch this.

## Evidence
- `app/jobs/ocpp/rails/remote_start_transaction_job.rb` → `ActionCable.server.broadcast("charge_point_#{charge_point.id}_outbound", …)`
- `app/jobs/ocpp/rails/remote_stop_transaction_job.rb` → same pattern
- `app/channels/ocpp/rails/charge_point_channel.rb` → `stream_for @charge_point` only

## Proposed fix
Unify the outbound stream. Either:
1. Have the channel `stream_from "charge_point_#{@charge_point.id}_outbound"` in addition to `stream_for`, and add a channel action / `received`-side handling that relays `{ message: … }` down the socket to the station; **or**
2. Have the jobs `ChargePointChannel.broadcast_to(charge_point, { message: … })` to match `stream_for`.

Whichever is chosen, the channel must actually forward the payload down the WebSocket to the station (currently it only *receives* from the station).

## Acceptance
- An integration test drives `RemoteStartTransactionJob.perform_now` and asserts the station socket receives the CALL frame (not just that a `Message` row exists).
- Same for remote stop.'

new_issue \
"No authentication of charge points on the WebSocket — station impersonation possible" \
"bug,security,critical,ocpp-1.6" \
'## Summary
`ChargePointChannel#subscribed` accepts a `charge_point_id` subscription param and the only "auth" is `ChargePoint.find_by(identifier: …)`. There is no TLS client certificate, no HTTP Basic Auth, and no per-station token. Any client that can reach the cable endpoint and supplies a known or guessed identifier is accepted as that station.

## Impact
Full station-impersonation / spoofing: an attacker can inject `StartTransaction`, `MeterValues`, and `StopTransaction` for any station identifier, corrupting sessions and meter data. OCPP Security Profile 1/2 is not implemented at all.

## Evidence
`app/channels/ocpp/rails/charge_point_channel.rb` — `reject` fires only when the identifier is unknown; no credential is ever checked. No `connection.rb` identification exists in the dummy app either.

## Proposed fix (1.6, incremental)
- Implement at least OCPP-J **Security Profile 1** (HTTP Basic Auth on the WS upgrade) as a first step, verified in `ApplicationCable::Connection#connect` before the channel subscribes.
- Store a per-station credential (hashed) on `ChargePoint`; reject on mismatch and log a security event.
- Document that WSS/TLS termination is required in front (Profile 2 = TLS + Basic Auth) and provide a config seam for client-cert verification.
- Constant-time comparison for the shared secret.

## Acceptance
- Connection without valid credentials is rejected before subscription.
- Connection with valid credentials for identifier X cannot subscribe as identifier Y.
- Failed auth attempts are logged.'

# ===========================================================================
# CORRECTNESS
# ===========================================================================

new_issue \
"transactionId type confusion: integer PK leaked on the wire, unique transaction_id UUID column unused" \
"bug,correctness,ocpp-1.6" \
'## Summary
Two competing identifiers exist for a session:
- DB column `transaction_id` (string, `unique`, auto-filled with a UUID via `before_create`).
- The OCPP wire `transactionId`, which `StartTransactionHandler` returns as `session.id` (the integer AR primary key).

`StopTransactionHandler` and `MeterValuesHandler` then look up via `find_by(id: transactionId)` — i.e. by PK, ignoring the `transaction_id` column entirely.

## Impact
- The unique UUID column is dead weight and misleads integrators.
- Sequential integer PKs are exposed as protocol transaction IDs (enumeration smell).
- Any code that assumes `transaction_id` is the wire ID is wrong.

## Evidence
- `app/services/ocpp/rails/actions/start_transaction_handler.rb` → `'"'"'transactionId'"'"' => session.id`
- `stop_transaction_handler.rb` / `meter_values_handler.rb` → `find_by(id: @payload['"'"'transactionId'"'"'])`
- `app/models/ocpp/rails/charging_session.rb` → `before_create :generate_transaction_id` (UUID)

## Proposed fix
Pick one identity scheme. Recommended: use an explicit integer `transaction_id` (OCPP 1.6 requires an integer transactionId) generated/managed by the CS, decouple it from the AR PK, and make lookups + uniqueness use that column. Remove the UUID generator or repurpose it as an opaque external reference — but not as the OCPP transactionId.

## Acceptance
- Wire `transactionId` is a value from a dedicated column, not the raw PK.
- Stop/MeterValues resolve the session via that same column.
- Test covers start→meter→stop using only the wire transactionId.'

new_issue \
"StartTransaction always returns Accepted, ignoring Authorize/hook result" \
"bug,correctness,ocpp-1.6" \
'## Summary
`StartTransactionHandler#call` unconditionally returns `idTagInfo.status = "Accepted"`, regardless of what the authorization hooks decided in `AuthorizeHandler`. A `Blocked`/`Invalid`/`Expired` idTag can still open a transaction.

## Impact
Authorization is effectively bypassed at transaction start; the hook system is decorative for `StartTransaction`. There is also no `Authorize`→`StartTransaction` correlation.

## Evidence
- `app/services/ocpp/rails/actions/start_transaction_handler.rb` → hardcoded `'"'"'status'"'"' => '"'"'Accepted'"'"'`
- `AuthorizationHookManager.execute_hooks` is only invoked from `AuthorizeHandler`.

## Proposed fix
- Run the same authorization decision (hooks) inside `StartTransactionHandler` for the presented `idTag`, and return the resulting status in `idTagInfo`.
- Only create the `ChargingSession` when status is `Accepted`.
- Optionally cache a recent `Authorize` decision per idTag to avoid double-evaluation.

## Acceptance
- A blocked idTag yields `idTagInfo.status != "Accepted"` and **no** session row.
- An accepted idTag starts the session as today.'

new_issue \
"No one-active-session-per-connector guard: duplicate StartTransaction opens concurrent sessions" \
"bug,correctness,ocpp-1.6" \
'## Summary
`StartTransactionHandler` calls `charging_sessions.create!` on every `StartTransaction` with no check for an existing active (non-stopped) session on the same connector, and there is no DB-level guard.

## Impact
Replayed or duplicate `StartTransaction` messages create multiple concurrent open sessions on one connector, corrupting energy/duration accounting. (Mirrors CPMS invariant: "one EVSE has at most one non-terminal session".)

## Proposed fix
- Before create, check for an existing active session on `(charge_point, connector_id)`; if present, resume/return it idempotently rather than creating a second.
- Add a partial unique index enforcing at most one row with `stopped_at IS NULL` per `(charge_point_id, connector_id)` (Postgres partial index).

## Acceptance
- Two `StartTransaction` for the same connector without an intervening stop result in exactly one active session.
- DB-level constraint prevents a second active row even under a race.'

new_issue \
"Naive energy calculation with no meter rollover / meter-swap detection" \
"bug,correctness,ocpp-1.6" \
'## Summary
`ChargingSession#calculate_energy_consumed` computes `stop_meter_value - start_meter_value` with no unit awareness, no register-rollover handling, and no meter-swap/implausible-jump detection. `MeterValuesHandler` stores raw values without sanity checks.

## Impact
Rollover (register wraps), meter replacement, or a nonsensical jump produces wrong or negative energy totals silently. No mechanism to quarantine a bad reading or flag the session for review.

## Proposed fix
- Validate monotonicity of the Energy.Active.Import.Register series per session; detect decreases/implausible deltas.
- On anomaly: flag the meter value / session for review rather than blindly subtracting.
- Be explicit about units (Wh vs kWh) and normalise.

## Acceptance
- A decreasing or wildly-jumping register value is flagged, not silently turned into negative/garbage energy.
- Normal monotonic series computes as today.'

new_issue \
"Unparseable OCPP timestamps silently fall back to Time.current, corrupting the series" \
"bug,correctness,ocpp-1.6" \
'## Summary
`parse_timestamp` in the meter/start/stop handlers rescues `ArgumentError/TypeError` and returns `Time.current`. A malformed or missing station timestamp is silently replaced with server time, with no flag.

## Impact
Fabricated timestamps enter the persisted time series undetected. For any later drift-correction or evidentiary use this is corrupting; it also masks station clock/firmware bugs.

## Proposed fix
- Persist both the raw station timestamp (as received) and the backend receive time.
- On parse failure, record the receive time AND flag the record (e.g. `timestamp_source = "server_fallback"`), never silently substitute.
- Log a warning with the raw value.

## Acceptance
- A bad timestamp produces a flagged record, not an unmarked server-time value.
- Raw station time is retained when present.'

# ===========================================================================
# HARDENING
# ===========================================================================

new_issue \
"No flood / reconnect-storm throttling on the OCPP ingress" \
"hardening,ocpp-1.6" \
'## Summary
There is no connection-rate limiting, jittered retry-after, or per-station message throttling. A reconnect storm (e.g. after a deploy drops sockets) or a chatty/malicious station is unbounded, and every inbound message writes a `Message` row synchronously on the socket path.

## Proposed fix
- Add per-station inbound message rate limiting.
- Add connection-rate limiting + jittered retry-after guidance for full-fleet reconnects.
- Consider moving raw-message audit writes off the hot path (async) and/or partitioning + capping retention.

## Acceptance
- A station exceeding a configurable message rate is throttled, not allowed to grow the DB unbounded.
- Documented reconnect behaviour for mass reconnect.'

new_issue \
"retry_on ..., :exponentially_longer is removed in Rails 8 — async hooks will not retry as intended" \
"bug,hardening,ocpp-1.6" \
'## Summary
`AsyncHookJob` and `AuthorizationAsyncHookJob` use `retry_on StandardError, wait: :exponentially_longer, attempts: 3`. `:exponentially_longer` is deprecated/removed in current Rails; the gem targets `rails >= 8.0`.

## Proposed fix
Replace with `wait: :polynomially_longer` (the Rails 8 successor) or an explicit lambda backoff. Add a test asserting the retry configuration is valid on the supported Rails version.

## Acceptance
- Jobs enqueue and retry without deprecation/removal errors on Rails 8.'

new_issue \
"send_callerror echoes internal exception messages to the station over the wire" \
"security,hardening,ocpp-1.6" \
'## Summary
`MessageHandler` sends `send_callerror(message_id, "InternalError", e.message)` on unexpected errors, leaking internal exception text (and potentially stack-relevant detail) to the peer.

## Proposed fix
- Return a generic OCPP error description over the wire; log the real exception server-side with a correlation id.
- Never place `e.message` in the CALLERROR description.

## Acceptance
- CALLERROR payloads contain only generic, protocol-appropriate descriptions.
- Full detail remains in server logs.'

new_issue \
"supported_versions default advertises 2.0/2.0.1/2.1 the code cannot speak" \
"correctness,hardening,ocpp-1.6" \
'## Summary
`Configuration#initialize` defaults `supported_versions = ["1.6", "2.0", "2.0.1", "2.1"]`, but only 1.6 is implemented. A `ChargePoint` can be persisted with `ocpp_protocol: "2.1"` (passes the inclusion validation) that the code cannot actually handle.

## Proposed fix
Until 2.x is implemented, default `supported_versions` to `["1.6"]` so the inclusion validation reflects real capability. Re-expand when 2.x lands.

## Acceptance
- Default config only advertises versions the gem can actually process.
- Creating a charge point with an unsupported protocol is rejected.'

echo ""
echo "Done. Review the created issues at: https://github.com/${REPO}/issues"
