# OCPP Rails Documentation

Welcome to the OCPP Rails documentation! This Rails engine provides an OCPP 1.6 **Central System** (CSMS) backend — the Core charging-session profile plus remote start/stop and connector unlock — for EV charging station management. See the [OCPP 1.6 Compliance Status](../README.md#-ocpp-16-compliance-status) and the [per-case test plan](octt-test-plan.md) for exactly what is (and isn't) implemented.

## 📚 Documentation

### Getting Started
- **[Installation & Setup](getting-started.md)** - Install the gem, run the generator, configure your application
- **[Configuration](configuration.md)** - All configuration options and environment setup
- **[Security](security.md)** - Charge point authentication (OCPP-J Security Profile 1) and TLS guidance
- **[ActionCable with SQLite](actioncable-sqlite.md)** - WebSocket configuration using SQLite (no Redis required)

### Implementation Guides  
- **[Real-Time Monitoring](real-time-monitoring.md)** - Monitor charge points, sessions, and meter values in real-time
- **[Remote Charging Guide](remote-charging.md)** - Complete implementation guide for remote start/stop with meter monitoring
- **[API Reference](api-reference.md)** - Models, jobs, and helper methods
- **[Message Reference](message-reference.md)** - OCPP message examples and JSON payloads

### Development
- **[Testing Guide](testing.md)** - Test suite overview, running tests, writing new tests
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions

### Reference
- **[OCTT Compliance Test Plan](octt-test-plan.md)** - Per-case OCPP 1.6 Central-System status (the source of truth)
- **[OCPP 1.6 Specification](../ocpp-1.6_edition_2.md)** - Full OCPP 1.6 Edition 2 specification
- **[Changelog](../CHANGELOG.md)** - Version history and release notes

## Quick Links

| Topic | Documentation |
|-------|---------------|
| First time setup | [Getting Started](getting-started.md) |
| Real-time monitoring | [Real-Time Monitoring](real-time-monitoring.md) |
| ActionCable/WebSocket setup | [ActionCable with SQLite](actioncable-sqlite.md) |
| Remote charging workflow | [Remote Charging Guide](remote-charging.md) |
| Database schema | [API Reference](api-reference.md#database-schema) |
| OCPP messages | [Message Reference](message-reference.md) |
| Running tests | [Testing Guide](testing.md) |
| Configuration options | [Configuration](configuration.md) |

## Documentation by User Type

### 🆕 New Users
1. Start with [Getting Started](getting-started.md)
2. Set up [ActionCable with SQLite](actioncable-sqlite.md)
3. Implement [Real-Time Monitoring](real-time-monitoring.md)
4. Review [Configuration](configuration.md)

### 👨‍💻 Developers
1. Read the [Real-Time Monitoring](real-time-monitoring.md) guide
2. Study the [API Reference](api-reference.md)
3. Review the [Message Reference](message-reference.md)
4. Check the [Testing Guide](testing.md)

### 🔧 DevOps/Operations
1. Review [Configuration](configuration.md)
2. Set up [ActionCable with SQLite](actioncable-sqlite.md)
3. Check [Troubleshooting](troubleshooting.md)
4. Monitor via [Real-Time Monitoring](real-time-monitoring.md)

## Features Overview

_See the [per-case OCTT test plan](octt-test-plan.md) for the authoritative status. **32 of 76**
OCTT Central-System cases are implemented and backed by real handler/job-driven tests._

### ✅ Implemented + tested
- Core inbound session flow: Boot, Authorize, Heartbeat, Start/StopTransaction, MeterValues, StatusNotification
- Remote start/stop transactions (delivery + end-to-end flow)
- UnlockConnector — release a connector, including during an active session
- Reset (Hard/Soft) and ClearCache — device reset and authorization-cache clearing
- GetConfiguration / ChangeConfiguration and ChangeAvailability (Operative/Inoperative)
- Real-time meter value monitoring (22+ measurands) + status / session broadcasts
- Session management, energy/duration tracking, meter-anomaly + timestamp-provenance checks
- Authorization support (RFID/ID tags) incl. Invalid / Expired / Blocked paths
- OCPP-J Security Profile 1 (HTTP Basic Auth) + per-station rate limiting
- Multi-connector support and a complete message audit trail

### 🔴 Not implemented yet
- Local authorization list sync (SendLocalList, GetLocalListVersion)
- Firmware updates + Diagnostics upload
- Reservation system (ReserveNow, CancelReservation)
- Remote Trigger (TriggerMessage)
- Smart charging profiles (Set/Clear/GetCompositeSchedule)
- Inbound DataTransfer handling
- Security profiles 2/3 (certificates, secure firmware, security events)
- Admin dashboard UI · OCPP 2.0.1 support

## Support

- **Issues**: [GitHub Issues](https://github.com/trahfo/ocpp-rails/issues)
- **Discussions**: [GitHub Discussions](https://github.com/trahfo/ocpp-rails/discussions)

## Contributing

Contributions are welcome! See our [Contributing Guide](../CONTRIBUTING.md) for details.

## Navigation

- **←** [Back to Main README](../README.md)
- **→** [Getting Started](getting-started.md)

---

**Last Updated**: 2025-10-17  
**Version**: 0.2.2  
**OCPP**: 1.6 Edition 2