# OCPP Rails Documentation

Welcome to the OCPP Rails documentation! This Rails engine provides complete OCPP 1.6 protocol implementation for EV charging station management.

## 📚 Documentation

### Getting Started
- **[Installation & Setup](getting-started.md)** - Install the gem, run the generator, configure your application
- **[Configuration](configuration.md)** - All configuration options and environment setup

### Implementation Guides  
- **[Remote Charging Guide](remote-charging.md)** - Complete implementation guide for remote start/stop with meter monitoring
- **[API Reference](api-reference.md)** - Models, controllers, jobs, and helper methods
- **[Message Reference](message-reference.md)** - OCPP message examples and JSON payloads

### Development
- **[Testing Guide](testing.md)** - Test suite overview, running tests, writing new tests
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions

### Reference
- **[OCPP 1.6 Specification](../ocpp-1.6_edition_2.md)** - Full OCPP 1.6 Edition 2 specification
- **[Changelog](../CHANGELOG.md)** - Version history and release notes

## Quick Links

| Topic | Documentation |
|-------|---------------|
| First time setup | [Getting Started](getting-started.md) |
| Remote charging workflow | [Remote Charging Guide](remote-charging.md) |
| Database schema | [API Reference](api-reference.md#database-schema) |
| OCPP messages | [Message Reference](message-reference.md) |
| Running tests | [Testing Guide](testing.md) |
| Configuration options | [Configuration](configuration.md) |

## Documentation by User Type

### 🆕 New Users
1. Start with [Getting Started](getting-started.md)
2. Follow the [Remote Charging Guide](remote-charging.md)
3. Review [Configuration](configuration.md)

### 👨‍💻 Developers
1. Read the [API Reference](api-reference.md)
2. Study the [Message Reference](message-reference.md)
3. Check the [Testing Guide](testing.md)

### 🔧 DevOps/Operations
1. Review [Configuration](configuration.md)
2. Check [Troubleshooting](troubleshooting.md)
3. Monitor via [Message Reference](message-reference.md)

## Features Overview

### ✅ Implemented (v0.1.0)
- Remote start/stop transactions
- Real-time meter value monitoring (22+ measurands)
- Session management and tracking
- Authorization support (RFID/ID tags)
- Complete message audit trail
- Multi-connector support
- Energy consumption calculations
- WebSocket communication (ActionCable)

### 🚧 In Development
- Status notification handling
- Configuration management
- Firmware updates
- Diagnostics upload

### 📝 Planned
- Reservation system
- Full smart charging profiles
- Local authorization list sync
- Admin dashboard UI
- OCPP 2.0.1 support

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/ocpp-rails/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/ocpp-rails/discussions)
- **Email**: support@example.com

## Contributing

Contributions are welcome! See our [Contributing Guide](../CONTRIBUTING.md) for details.

## Navigation

- **←** [Back to Main README](../README.md)
- **→** [Getting Started](getting-started.md)

---

**Last Updated**: 2024-01-15  
**Version**: 0.1.0  
**OCPP**: 1.6 Edition 2