# OCPP Rails Testing Guide

How to run and write tests for OCPP Rails. For **per-case compliance coverage**
(what OCTT cases pass and what's still missing), the single source of truth is the
[OCTT Compliance Test Plan](octt-test-plan.md) — this guide does not duplicate those
numbers.

**Navigation**: [← Back to Documentation Index](README.md) | [API Reference →](api-reference.md)

## Running the suite

```bash
bin/rails test                                       # everything
bin/rails test test/ocpp                             # just the OCPP tests
bin/rails test test/ocpp/message_handler_test.rb     # one file
bin/rails test test/ocpp/message_handler_test.rb:42  # one test, by line number
```

To see the current pass count and timing, just run it — the suite is fast (about a
second). We deliberately don't quote a fixed test count here; it drifts every release.

> **Gotcha:** tests share one SQLite database (`test/dummy/storage/test.sqlite3`),
> run single-process and transactional (no `parallelize`), with a 5s busy-timeout.
> Launching several test processes at once can raise a transient
> `SQLite3::BusyException: database is locked` — just re-run.

## Two kinds of tests — and why the distinction matters

This is the most important thing to understand about the suite.

- **Handler/job-driven tests** push a real frame through `MessageHandler`, an
  `Actions::*Handler`, or an outbound job and assert on the actual behavior. **These
  are the ones that count as OCTT coverage** in [octt-test-plan.md](octt-test-plan.md).
  Examples: `message_handler_test.rb`, `boot_notification_handler_test.rb`,
  `authorize_handler_test.rb`, `status_notification_handler_test.rb`,
  `outbound_delivery_test.rb`, `station_authentication_test.rb`, the `*_job_test.rb`
  files, and the flow tests under `integration/` (`remote_start_flow_test.rb`,
  `remote_stop_flow_test.rb`, `offline_transaction_test.rb`,
  `power_failure_recovery_test.rb`).

- **Simulation-style tests** — the older files under `test/ocpp/integration/`
  (`authorize_test.rb`, `boot_notification_test.rb`, `*_transaction_test.rb`,
  `meter_values_test.rb`, `remote_charging_session_workflow_test.rb`, etc.) build
  request/response hashes and model rows *by hand* without invoking production code.
  They document expected message shapes but prove nothing about wire-protocol
  compliance, so they are **not** counted as coverage.

When you add coverage for a case, write a **handler/job-driven** test.

## Layout

```
test/
├── ocpp/
│   ├── *_test.rb              # handler & job unit tests (the real ones)
│   └── integration/*_test.rb  # end-to-end flow tests + older simulation-style tests
└── support/
    └── ocpp_test_helper.rb    # factories, message builders, frame builders, assertions
```

## The test helper

`test/support/ocpp_test_helper.rb` (`module OcppTestHelper`) provides:

- **Factories** — `create_charge_point`, `create_charging_session`, `create_meter_value`.
- **Message builders** — `build_<action>_request` / `build_<action>_response` helpers
  for constructing OCPP payloads in tests. (Builders exist for many operations,
  including ones not yet implemented in the engine — a builder is just a payload
  fixture, not proof the operation is supported.)
- **Frame builders** — `build_call_message`, `build_callresult_message`,
  `build_callerror_message`, and `parse_ocpp_message` for the OCPP-J wire format.
- **Assertions** — `assert_valid_call_message`, `assert_valid_callresult_message`,
  `assert_valid_callerror_message`.
- **Constants** — `OCPP_ERROR_CODES`, `REGISTRATION_STATUS`, `AUTHORIZATION_STATUS`,
  `CHARGE_POINT_STATUS`, `CHARGE_POINT_ERROR_CODE`.

Open the file for the exact, current signatures rather than relying on a copy here.

## Adding a test for a new OCTT case

1. Find the case in [octt-test-plan.md](octt-test-plan.md). Each 🔴/🟡 case has a
   Given/When/Then (Gherkin) spec you can turn into a test without re-reading the OCTT PDF.
2. If the message/operation isn't implemented yet, build it first (an
   `Actions::<Action>Handler` for inbound, or a `<Operation>Job` for outbound — see
   the [main README architecture notes](../README.md) and existing handlers/jobs).
3. Write a **handler/job-driven** test (see above) — name it `<thing>_test.rb`, place
   handler/job unit tests directly under `test/ocpp/` and multi-message flows under
   `test/ocpp/integration/`, and `include OcppTestHelper`.
4. Update the case's status and test-file reference in
   [octt-test-plan.md](octt-test-plan.md); the README's headline numbers mirror that file.

## References

- **[OCTT Compliance Test Plan](octt-test-plan.md)** — per-case status and Gherkin specs (source of truth)
- **[OCPP 1.6 Compliance Status](../README.md#-ocpp-16-compliance-status)** — the headline numbers
- [OCPP 1.6 specification & profiles](https://www.openchargealliance.org/protocols/ocpp-16/) — from the Open Charge Alliance

---

**Next**: [Troubleshooting Guide](troubleshooting.md) →  
**Back**: [Documentation Index](README.md) ←
