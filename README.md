# OCPP Rails

[![Tests](https://img.shields.io/badge/tests-208%20passing-brightgreen)]()
[![Coverage](https://img.shields.io/badge/coverage-45%25-yellow)]()
[![OCPP](https://img.shields.io/badge/OCPP-1.6-blue)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Ruby on Rails engine that provides complete OCPP 1.6 protocol implementation for Electric Vehicle (EV) charging station management systems. This is a **backend-only gem** - you build your own UI while OCPP Rails handles all WebSocket communication, data models, and OCPP protocol compliance.

## ✨ Features

### OCPP Protocol Layer (What This Gem Provides)
- 📡 **WebSocket Communication** - ActionCable channel handles bidirectional OCPP messages
- 🔌 **Protocol Handlers** - BootNotification, Authorize, Heartbeat, StartTransaction, StopTransaction, MeterValues, StatusNotification
- 🗄️ **Data Models** - ChargePoint, ChargingSession, MeterValue, Message (audit log)
- 🚀 **Remote Control Jobs** - RemoteStartTransaction, RemoteStopTransaction
- 📊 **Real-time Broadcasts** - ActionCable broadcasts for status, sessions, and meter values
- 💾 **SQLite Compatible** - Works with async adapter, no Redis required for development

### What You Build (Your Application)
- 🎨 **User Interface** - Build your own dashboard, charts, and controls
- 🔐 **Authentication** - Implement your own user authentication
- 📱 **API Endpoints** - Create REST/GraphQL APIs as needed
- 💼 **Business Logic** - Billing, reservations, user management, etc.
- 🎯 **Custom Authorization** - Override handlers for RFID validation logic

### OCPP Compliance
- ✅ **Core Profile** - All essential messages implemented
- ✅ **Remote Control** - RemoteStartTransaction, RemoteStopTransaction
- ✅ **Message Audit** - Complete logging for debugging and compliance
- ✅ **Multi-connector** - Handle multiple simultaneous charging sessions

## 📋 OCPP 1.6 Compliance

| Profile | Status | Messages |
|---------|--------|----------|
| **Core Profile** | 60% | Authorize, BootNotification, Heartbeat, MeterValues, Start/StopTransaction |
| **Remote Control** | ✅ 100% | RemoteStartTransaction, RemoteStopTransaction |
| **Smart Charging** | 🚧 Partial | Charging profiles in RemoteStart |
| **Firmware Management** | 📝 Planned | UpdateFirmware, GetDiagnostics |
| **Reservation** | 📝 Planned | ReserveNow, CancelReservation |
| **Local Auth List** | 📝 Planned | SendLocalList, GetLocalListVersion |

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

For detailed setup instructions, see the [Getting Started Guide](docs/getting-started.md).

## 💡 Usage Examples

### Monitor Charge Point Status

```ruby
# Query charge points
connected_cps = Ocpp::Rails::ChargePoint.connected
available_cps = Ocpp::Rails::ChargePoint.available
charging_cps = Ocpp::Rails::ChargePoint.charging

# Check specific charge point
cp = Ocpp::Rails::ChargePoint.find_by(identifier: "CP001")
cp.connected?       # => true/false
cp.status           # => "Available", "Charging", etc.
cp.last_heartbeat_at
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
  session.id
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
  - Has many charging sessions and meter values
  - Provides status scopes (connected, available, charging)

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

The gem includes a comprehensive test suite covering all implemented OCPP operations:

```bash
# Run all tests
rails test

# Run only OCPP integration tests
rails test test/ocpp/integration/

# Run specific test file
rails test test/ocpp/integration/remote_charging_session_workflow_test.rb
```

**Current Test Coverage:**
- 📊 **208 tests** across 9 test files
- ✅ **646 assertions**, 0 failures
- 🎯 **100% passing** for implemented features

See the [Testing Guide](docs/testing.md) for detailed information.

## 🗺️ Roadmap

### Current Release (v0.1.0)
- ✅ Remote start/stop transactions
- ✅ Real-time meter value monitoring
- ✅ Session management and tracking
- ✅ Authorization support
- ✅ Complete message logging

### Planned Features
- 📝 Configuration management (Get/ChangeConfiguration)
- 📝 Firmware updates
- 📝 Diagnostics upload
- 📝 Reservation system
- 📝 Full smart charging profile management
- 📝 Local authorization list sync
- 📝 WebSocket connection management UI
- 📝 Admin dashboard
- 📝 OCPP 2.0.1 support

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

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
**Version**: 0.1.0  
**OCPP**: 1.6 Edition 2  
**Rails**: 7.0+  
**Ruby**: 3.0+