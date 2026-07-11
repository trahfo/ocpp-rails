# OCPP Rails

[![OCPP](https://img.shields.io/badge/OCPP-1.6-blue)]()
[![OCTT CS coverage](https://img.shields.io/badge/OCTT%20Central%20System-32%2F76%20cases-orange)](docs/octt-test-plan.md)
[![Status](https://img.shields.io/badge/status-alpha-yellow)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Ruby on Rails engine for building OCPP 1.6 **Central System** (CSMS) backends for
Electric Vehicle (EV) charging networks. This is a **backend-only gem** — you build
your own UI while OCPP Rails handles the WebSocket transport, data models, and the
OCPP message layer.

> **⚠️ Early alpha — read the compliance status before you rely on this.**
> The Core charging-session flow (boot, authorize, start/stop transaction, meter
> values, status), remote start/stop, and connector unlock are implemented **and
> covered by real handler/job-driven tests**. **Most other Central-System→Charge-Point
> operations and every optional feature profile (Reservation, Smart Charging,
> Firmware, Diagnostics, Local Auth List, Security certificates) are not implemented yet.**
> See [OCPP 1.6 Compliance Status](#-ocpp-16-compliance-status) for the exact,
> per-test-case picture — and please consider [contributing](#-contributing) a slice.

## ✨ Features

### OCPP Protocol Layer (What This Gem Provides)
- 📡 **WebSocket Communication** - ActionCable channel handles bidirectional OCPP messages
- 🔌 **Protocol Handlers** - BootNotification, Authorize, Heartbeat, StartTransaction, StopTransaction, MeterValues, StatusNotification
- 🗄️ **Data Models** - ChargePoint, ConnectorStatus, ChargingSession, MeterValue, Message (audit log)
- 🪝 **Lifecycle Hooks** - authorization, state-change, and session-start/stop hooks (sync or async via ActiveJob) — react without polling
- 🚀 **Remote Control Jobs** - RemoteStartTransaction, RemoteStopTransaction, UnlockConnector, Reset, ClearCache, GetConfiguration, ChangeConfiguration, ChangeAvailability
- 📊 **Real-time Broadcasts** - ActionCable broadcasts for status, sessions, and meter values
- 💾 **SQLite Compatible** - Works with async adapter, no Redis required for development

### What You Build (Your Application)
- 🎨 **User Interface** - Build your own dashboard, charts, and controls
- 🔐 **Authentication** - Implement your own user authentication
- 📱 **API Endpoints** - Create REST/GraphQL APIs as needed
- 💼 **Business Logic** - Billing, reservations, user management, etc.
- 🎯 **Custom Authorization** - Override handlers for RFID validation logic

### OCPP Compliance
- ✅ **Core session flow** — inbound BootNotification, Authorize, Heartbeat, Start/StopTransaction, MeterValues, StatusNotification
- ✅ **Remote Control** — RemoteStartTransaction, RemoteStopTransaction, UnlockConnector (delivery + end-to-end flow, tested)
- ✅ **Message Audit** — every inbound/outbound frame logged for debugging and compliance
- ✅ **Multi-connector** — one active session per connector, enforced at the DB level; per-connector status tracked independently of whole-station status
- 🚧 **Everything else** — see the honest, per-test-case [OCPP 1.6 Compliance Status](#-ocpp-16-compliance-status) below

## 📋 OCPP 1.6 Compliance Status

Compliance here is measured against the Open Charge Alliance **OCPP Compliance Testing
Tool (OCTT)** test case document (2025-02), Section 3 — the cases that apply when the
*System Under Test is the Central System*. There are **76** such cases. This is the
role `ocpp-rails` fills, so it is the right yardstick.

**Where we are today:**

| | Cases | What it means |
|---|---:|---|
| ✅ **Implemented + tested** | 32 | Works and guarded by a real handler/job-driven test |
| 🟡 **Implemented — needs test** | 0 | Behavior works, but only simulation-style tests exist; needs a real regression test |
| 🔴 **Not implemented** | 42 | The message/operation does not exist in the engine yet |
| ⚪ **Out of scope** | 2 | TLS handshake (TC_086/087) — belongs in your infra, not app code |

So **32 of 76 OCTT Central-System cases (42%) are backed by working code**, and every
one now has real automated (handler/job-driven) coverage — the 🟡 bucket is empty. The
entire Core outbound command set is done; the rest — Local Auth List, Firmware,
Diagnostics, Reservation, Remote Trigger, Smart Charging, DataTransfer and the Security
profiles 2/3 — is **not built yet**. Treat this gem as a solid, well-tested Core-profile
foundation to build on, not a certified CSMS.

**By feature area** (each links to the detailed Given/When/Then specs):

| Area | Status | Notes |
|---|---|---|
| [Boot / Charging Sessions / Cache](docs/octt-test-plan.md#1-boot-charging-sessions-cache) | ✅ implemented + tested | Core flow **and** ClearCache tested end-to-end |
| [Remote Start / Stop](docs/octt-test-plan.md#2-remote-start--stop) | ✅ implemented + tested | delivery **and** end-to-end session flow tested |
| [Reset / Unlock / Configuration](docs/octt-test-plan.md#3-reset--unlock--configuration-core-profile) | ✅ implemented + tested | Reset, UnlockConnector, Get/ChangeConfiguration all tested (+ ChangeAvailability) |
| [Authorize non-happy paths](docs/octt-test-plan.md#4-authorize-non-happy-paths) | ✅ tested | Invalid / Expired / Blocked on Authorize.req tested |
| [Offline / power-loss](docs/octt-test-plan.md#5-offline--power-loss-behavior) | ✅ tested | replay + power-loss recovery sequences tested |
| [Local Authorization List](docs/octt-test-plan.md#6-local-authorization-list) | 🔴 not implemented | no SendLocalList / GetLocalListVersion |
| [Firmware Management](docs/octt-test-plan.md#7-firmware-management) | 🔴 not implemented | no UpdateFirmware / FirmwareStatusNotification |
| [Diagnostics](docs/octt-test-plan.md#8-diagnostics) | 🔴 not implemented | no GetDiagnostics / DiagnosticsStatusNotification |
| [Reservation](docs/octt-test-plan.md#9-reservation) | 🔴 not implemented | no ReserveNow / CancelReservation, no model |
| [Remote Trigger](docs/octt-test-plan.md#10-remotetrigger) | 🔴 not implemented | no TriggerMessage |
| [Smart Charging](docs/octt-test-plan.md#11-smart-charging) | 🔴 not implemented | no SetChargingProfile / ClearChargingProfile / GetCompositeSchedule |
| [DataTransfer](docs/octt-test-plan.md#12-datatransfer) | 🔴 not implemented | inbound DataTransfer currently gets a NotSupported CALLERROR |
| [Security (profiles 1–3)](docs/octt-test-plan.md#13-security-profiles-13) | 🟡 Basic auth only | HTTP Basic Auth works + tested; certificates/secure firmware/TLS not |

👉 **Full per-test-case breakdown with Given/When/Then specs:** [docs/octt-test-plan.md](docs/octt-test-plan.md).
It doubles as a ready-made contribution backlog — every 🔴 and 🟡 is a self-contained PR.

## 🚀 Quick Start

### Installation

Add this line to your application's Gemfile:

```ruby
gem "ocpp-rails"
```

Execute the bundle command:

```bash
bundle install
```

### Setup

Run the installation generator:

```bash
rails generate ocpp:rails:install
```

This will:
- ✅ Create database migrations for charge points, sessions, and meter values
- ✅ Mount the engine at `/ocpp` (ActionCable WebSocket endpoint)
- ✅ Generate an initializer at `config/initializers/ocpp_rails.rb`
- ✅ Configure ActionCable for SQLite compatibility
- ✅ Display setup instructions

Run the migrations:

```bash
rails db:migrate
```

### Configuration

Configure OCPP settings in `config/initializers/ocpp_rails.rb`:

```ruby
Ocpp::Rails.setup do |config|
  config.ocpp_version = "1.6"
  config.supported_versions = ["1.6"]
  config.heartbeat_interval = 300  # 5 minutes
  config.connection_timeout = 30   # 30 seconds
end
```

**Charge points connect to:**
```
ws://your-server:3000/ocpp/cable
```

Stations authenticate with HTTP Basic Auth on the WebSocket upgrade
(OCPP-J Security Profile 1, enabled by default). Provision a per-station
credential first:

```ruby
charge_point.update!(auth_password: SecureRandom.base58(32))
```

For detailed setup instructions, see the [Getting Started Guide](docs/getting-started.md)
and the [Security Guide](docs/security.md).

## 💡 Usage Examples

### Monitor Charge Point Status

`ChargePoint#status` is the whole-station status (from connector-0
StatusNotifications: Available/Unavailable/Faulted) — it says nothing about
any individual connector once a station has more than one.

```ruby
# Query charge points
connected_cps = Ocpp::Rails::ChargePoint.connected
available_cps = Ocpp::Rails::ChargePoint.available
charging_cps = Ocpp::Rails::ChargePoint.charging  # any active session, any connector

# Check specific charge point
cp = Ocpp::Rails::ChargePoint.find_by(identifier: "CP001")
cp.connected?       # => true/false
cp.status           # => whole-station status: "Available", "Unavailable", "Faulted"
cp.last_heartbeat_at

# Per-connector status (independent of any other connector on the same station)
cp.connector_status(1)      # => "Available", "Charging", "SuspendedEV", ...
cp.connector_charging?(1)   # => true/false, derived from active sessions
```

### Monitor Active Sessions

```ruby
# Get active sessions
active_sessions = Ocpp::Rails::ChargingSession.active

# Get session details
session = cp.current_session
session.connector_id
session.energy_consumed  # kWh
session.duration_seconds
```

### Monitor Meter Values

```ruby
# Get latest readings
latest_energy = cp.meter_values.energy.recent.first
latest_power = cp.meter_values.power.recent.first

# Get readings for a session
session.meter_values.order(:timestamp)
```

### Real-Time Updates via ActionCable

Subscribe to real-time broadcasts in your UI:

```ruby
# app/channels/meter_values_channel.rb
class MeterValuesChannel < ApplicationCable::Channel
  def subscribed
    charge_point = Ocpp::Rails::ChargePoint.find(params[:charge_point_id])
    stream_from "charge_point_#{charge_point.id}_meter_values"
  end
end
```

```javascript
// Subscribe in JavaScript
subscribeToMeterValues(chargePointId, {
  onPower: (data) => {
    updatePowerGauge(data.value);
  },
  onEnergy: (data) => {
    updateEnergyCounter(data.value);
  }
});
```

### Remote Control

```ruby
# Start a charging session
charge_point = Ocpp::Rails::ChargePoint.find_by(identifier: "CP001")

Ocpp::Rails::RemoteStartTransactionJob.perform_later(
  charge_point.id,
  1,              # connector_id
  "RFID12345"     # id_tag
)

# Stop a charging session
session = charge_point.current_session
Ocpp::Rails::RemoteStopTransactionJob.perform_later(
  charge_point.id,
  session.transaction_id
)
```

For complete implementation examples, see the [Remote Charging Guide](docs/remote-charging.md).

## 📚 Documentation

### Getting Started
- **[Installation & Setup Guide](docs/getting-started.md)** - Detailed installation, configuration, and first steps
- **[Configuration Options](docs/configuration.md)** - Complete configuration reference

### Implementation Guides
- **[Real-Time Monitoring Guide](docs/real-time-monitoring.md)** - Monitor charge points, sessions, and meter values in real-time
- **[Remote Charging Implementation](docs/remote-charging.md)** - Complete guide to remote charging workflow with message diagrams
- **[ActionCable with SQLite](docs/actioncable-sqlite.md)** - WebSocket configuration using SQLite (no Redis required)
- **[API Reference](docs/api-reference.md)** - Models, jobs, and helper methods
- **[Message Reference](docs/message-reference.md)** - OCPP message examples and payloads

### Development
- **[Testing Guide](docs/testing.md)** - Running tests, writing new tests, test coverage
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions

### Reference
- **[OCPP 1.6 Specification](ocpp-1.6_edition_2.md)** - Full OCPP 1.6 Edition 2 specification
- **[Documentation Index](docs/README.md)** - Complete documentation overview

## 🏗️ Architecture

### Models

- **`Ocpp::Rails::ChargePoint`** - Represents a physical charging station
  - Tracks connection status, firmware version, vendor info
  - Has many charging sessions, connector statuses, and meter values
  - Provides status scopes (connected, available, charging) and per-connector reads (`connector_status`, `connector_charging?`)

- **`Ocpp::Rails::ConnectorStatus`** - Last reported status for one connector
  - One row per `(charge_point, connector_id)`, written by StatusNotification
  - Independent of whole-station status and of any other connector's activity

- **`Ocpp::Rails::ChargingSession`** - Represents a charging transaction
  - Manages session lifecycle (active/completed)
  - Calculates energy consumption and duration automatically
  - Links to meter values for detailed tracking

- **`Ocpp::Rails::MeterValue`** - Stores individual meter readings
  - Supports 22+ OCPP measurands (Energy, Power, Current, Voltage, SoC, Temperature, etc.)
  - Can be transaction-specific or standalone
  - Includes timestamp, phase, context, and location

- **`Ocpp::Rails::Message`** - Logs all OCPP communications
  - Stores direction (inbound/outbound)
  - Includes full message payload as JSONB
  - Enables debugging and compliance auditing

### Communication Flow

```
┌─────────────────┐                    ┌─────────────────┐
│  Your Rails App │                    │  Charge Point   │
│  (Central System)│                   │     (OCPP 1.6)  │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         │  1. RemoteStartTransaction           │
         ├─────────────────────────────────────>│
         │                                      │
         │  2. StartTransaction                 │
         │<─────────────────────────────────────┤
         │                                      │
         │  3. MeterValues (periodic)           │
         │<─────────────────────────────────────┤
         │                                      │
         │  4. RemoteStopTransaction            │
         ├─────────────────────────────────────>│
         │                                      │
         │  5. StopTransaction                  │
         │<─────────────────────────────────────┤
```

## 🧪 Testing

```bash
# Run all tests
rails test

# Run the handler/job-driven unit tests (the ones that exercise real code)
rails test test/ocpp/

# Run a specific test file
rails test test/ocpp/outbound_delivery_test.rb
```

**A note on what the tests prove.** The suite has two kinds of tests:

- **Handler/job-driven tests** push real frames through
  `MessageHandler`/`Actions::*Handler`/jobs and assert on actual behavior — e.g.
  `test/ocpp/message_handler_test.rb`, `outbound_delivery_test.rb`,
  `station_authentication_test.rb`, `start_transaction_authorization_test.rb`,
  `authorize_handler_test.rb`, `boot_notification_handler_test.rb`,
  `status_notification_handler_test.rb`, `unlock_connector_job_test.rb`, and several
  under `test/ocpp/integration/` (`remote_start_flow_test.rb`, `remote_stop_flow_test.rb`,
  `offline_transaction_test.rb`, `power_failure_recovery_test.rb`). **These are what the
  compliance status above counts.**
- **Simulation-style tests** — the older files under `test/ocpp/integration/` (e.g.
  `*_transaction_test.rb`, `remote_charging_session_workflow_test.rb`, `authorize_test.rb`,
  `boot_notification_test.rb`) build request/response hashes and model rows by hand
  *without* invoking production code. They document expected message shapes but do **not**
  prove wire-protocol compliance, so they are not counted toward OCTT coverage.

When you implement a 🔴/🟡 case from the [test plan](docs/octt-test-plan.md), please add
a **handler/job-driven** test for it. See the [Testing Guide](docs/testing.md) for details.

## 🗺️ Roadmap

### Implemented today
- ✅ Core inbound session flow (Boot, Authorize, Heartbeat, Start/StopTransaction, MeterValues, StatusNotification)
- ✅ Remote start/stop transactions (delivery + end-to-end flow) and UnlockConnector — releasable even during an active session
- ✅ Device management: Reset (Hard/Soft), ClearCache, ChangeAvailability, and Get/ChangeConfiguration
- ✅ Real-time meter value / status / session broadcasts
- ✅ Session management, energy/duration tracking, meter-anomaly + timestamp-provenance checks
- ✅ OCPP-J Security Profile 1 (HTTP Basic Auth) + per-station rate limiting
- ✅ Complete inbound/outbound message logging
- ✅ Handler/job-driven OCTT regression suite for all 32 implemented Core-profile cases

### Not implemented yet (contributions very welcome — see the [test plan](docs/octt-test-plan.md))
- 🔴 Local Authorization List (SendLocalList, GetLocalListVersion)
- 🔴 Firmware updates + FirmwareStatusNotification
- 🔴 Diagnostics upload + DiagnosticsStatusNotification
- 🔴 Reservation system (ReserveNow, CancelReservation)
- 🔴 Remote Trigger (TriggerMessage)
- 🔴 Smart charging profile management (Set/Clear/GetCompositeSchedule)
- 🔴 Inbound DataTransfer handling
- 🔴 Security profiles 2/3 (certificate management, secure firmware, security events)
- 📝 OCPP 2.0.1 support

## 🤝 Contributing

**This project needs you.** It's an honest, well-tested Core-profile foundation with a
long list of OCPP features still to build — and that list is already written up as a
ready-to-pick-up backlog.

### Where to start

[**docs/octt-test-plan.md**](docs/octt-test-plan.md) maps all 76 OCTT Central-System
test cases to their status. Every 🔴 (*not implemented*) and 🟡 (*needs a real test*)
entry comes with a Given/When/Then spec and a suggested test file — so each one is a
self-contained, well-scoped PR. Good first issues:

- **🟡 Add a real test** for something that already works — pick a 🟡 case (e.g. the
  Authorize non-happy paths, or the boot flow) and write a handler-driven test against
  the spec. No new production code needed.
- **🔴 Implement one operation** — the outbound Core command set is complete; the next
  self-contained targets are Remote Trigger (`TriggerMessage`) and the Local Auth List
  commands (`GetLocalListVersion`, `SendLocalList`), following the same job pattern as
  `RemoteStartTransactionJob` / `ResetJob`.
- **🔴 Build out a feature profile** — Reservation, Smart Charging, Firmware, etc. are
  larger efforts; open an issue first so we can sketch the model/API together.

### Ground rules

- Match the OCTT spec in the test plan — cite the `TC_xxx_CSMS` id in your PR.
- Add a **handler/job-driven** test (not a simulation-style hash test) for any behavior
  you implement, and update the case's status in `docs/octt-test-plan.md` and the summary
  in this README.
- For major changes, open an issue first to discuss the design.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/trahfo/ocpp-rails.git
cd ocpp-rails

# Install dependencies
bundle install

# Setup test database
cd test/dummy
rails db:migrate RAILS_ENV=test
cd ../..

# Run tests
rails test
```

### Running the Test Suite

```bash
# Run all tests with coverage
rails test

# Run with verbose output
rails test -v

# Run specific test file
rails test test/ocpp/integration/remote_charging_session_workflow_test.rb
```

## 📄 License

This gem is available as open source under the terms of the [MIT License](LICENSE).

## 🙏 Acknowledgments

- [Open Charge Alliance](https://www.openchargealliance.org/) for the OCPP specification
- Built with ❤️ for the EV charging community

## 📞 Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/trahfo/ocpp-rails/issues)
- **Discussions**: [GitHub Discussions](https://github.com/trahfo/ocpp-rails/discussions)

## 🔗 Links

- [Changelog](CHANGELOG.md)
- [OCPP 1.6 Specification](ocpp-1.6_edition_2.md)
- [Complete Documentation](docs/README.md)
- [API Documentation](docs/api-reference.md)

---

**Status**: 🔧 Alpha - Under Active Development  
**Version**: 0.2.0  
**OCPP**: 1.6 Edition 2  
**Rails**: 8.0+  
**Ruby**: 3.3+