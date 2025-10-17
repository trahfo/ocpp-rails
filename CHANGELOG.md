# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/trahfo/ocpp-rails/releases/tag/v0.1.0
