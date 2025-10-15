# Getting Started with OCPP Rails

This guide will walk you through installing and configuring OCPP Rails in your Rails application.

## Prerequisites

Before you begin, make sure you have:

- **Ruby** 3.0 or higher
- **Rails** 7.0 or higher
- **Database**: PostgreSQL, MySQL, or SQLite (for development)
- **Redis**: Required for ActionCable/WebSocket communication
- **Git**: For version control

## Installation

### Step 1: Add the Gem

Add OCPP Rails to your `Gemfile`:

```ruby
gem 'ocpp-rails'
```

Then install it:

```bash
bundle install
```

### Step 2: Run the Install Generator

OCPP Rails includes a generator that sets up everything you need:

```bash
rails generate ocpp:rails:install
```

The generator will:

✅ **Create Database Migrations**
- `create_ocpp_charge_points.rb` - Charge point registry
- `create_ocpp_charging_sessions.rb` - Charging session records
- `create_ocpp_meter_values.rb` - Meter reading storage
- `create_ocpp_messages.rb` - OCPP message audit log

✅ **Mount the Engine**
- Adds `mount Ocpp::Rails::Engine => '/ocpp_admin'` to your `config/routes.rb`

✅ **Create Initializer**
- Generates `config/initializers/ocpp_rails.rb` with default configuration

✅ **Display Setup Instructions**
- Shows next steps and configuration tips

### Step 3: Run Database Migrations

Apply the migrations to create the necessary tables:

```bash
rails db:migrate
```

This creates four tables:

| Table | Purpose |
|-------|---------|
| `ocpp_charge_points` | Stores charge point information (vendor, model, status, connection state) |
| `ocpp_charging_sessions` | Tracks charging sessions with energy and duration |
| `ocpp_meter_values` | Stores periodic meter readings during charging |
| `ocpp_messages` | Logs all OCPP messages for debugging and compliance |

### Step 4: Configure Redis (Required for WebSockets)

OCPP Rails uses ActionCable for real-time WebSocket communication with charge points.

#### Install Redis

**macOS (Homebrew):**
```bash
brew install redis
brew services start redis
```

**Ubuntu/Debian:**
```bash
sudo apt-get install redis-server
sudo systemctl start redis
```

**Docker:**
```bash
docker run -d -p 6379:6379 redis:alpine
```

#### Configure ActionCable

Edit `config/cable.yml`:

```yaml
development:
  adapter: redis
  url: redis://localhost:6379/1

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: myapp_production
```

Verify Redis is running:

```bash
redis-cli ping
# Should respond with: PONG
```

### Step 5: Configure OCPP Settings

Edit the generated initializer at `config/initializers/ocpp_rails.rb`:

```ruby
Ocpp::Rails.setup do |config|
  # OCPP protocol version to use
  config.ocpp_version = "1.6"
  
  # List of supported OCPP versions
  config.supported_versions = ["1.6", "2.0", "2.0.1", "2.1"]
  
  # Heartbeat interval in seconds (how often charge points send heartbeats)
  config.heartbeat_interval = 300  # 5 minutes
  
  # Connection timeout in seconds
  config.connection_timeout = 30
end
```

**Configuration Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `ocpp_version` | `"1.6"` | Default OCPP version |
| `supported_versions` | `["1.6", ...]` | Versions your system supports |
| `heartbeat_interval` | `300` | Seconds between heartbeats |
| `connection_timeout` | `30` | Timeout for charge point responses |

## Verify Installation

### Check Database Tables

```bash
rails dbconsole
```

Then run:

```sql
-- PostgreSQL/MySQL
SHOW TABLES LIKE 'ocpp_%';

-- SQLite
.tables
```

You should see:
- `ocpp_charge_points`
- `ocpp_charging_sessions`
- `ocpp_meter_values`
- `ocpp_messages`

### Check Routes

```bash
rails routes | grep ocpp
```

You should see the mounted engine routes including:
```
ocpp_admin     /ocpp_admin     Ocpp::Rails::Engine
```

### Access Admin Interface

Start your Rails server:

```bash
rails server
```

Visit: `http://localhost:3000/ocpp_admin`

You should see the OCPP Rails dashboard (may be empty until you create charge points).

## Create Your First Charge Point

### Using Rails Console

```bash
rails console
```

```ruby
# Create a charge point
charge_point = Ocpp::Rails::ChargePoint.create!(
  identifier: "CP_001",
  vendor: "ABB",
  model: "Terra 54",
  serial_number: "SN123456789",
  firmware_version: "1.0.0",
  ocpp_protocol: "1.6",
  status: "Available",
  connected: false
)

puts "Created charge point: #{charge_point.identifier}"
```

### Using Seeds File

Add to `db/seeds.rb`:

```ruby
# Create demo charge points
["CP_001", "CP_002", "CP_003"].each do |identifier|
  Ocpp::Rails::ChargePoint.find_or_create_by!(identifier: identifier) do |cp|
    cp.vendor = "Demo Vendor"
    cp.model = "Demo Model"
    cp.serial_number = "SN#{SecureRandom.hex(6)}"
    cp.firmware_version = "1.0.0"
    cp.ocpp_protocol = "1.6"
    cp.status = "Available"
    cp.connected = false
  end
end

puts "Created #{Ocpp::Rails::ChargePoint.count} charge points"
```

Then run:

```bash
rails db:seed
```

## Test Your Installation

### Send a Test Remote Start Command

```ruby
# In Rails console
charge_point = Ocpp::Rails::ChargePoint.first

# Queue a remote start command
Ocpp::Rails::RemoteStartTransactionJob.perform_later(
  charge_point.id,
  1,                    # connector_id
  "RFID_TEST_001"      # id_tag
)

# Check the message was created
Ocpp::Rails::Message.where(
  charge_point: charge_point,
  action: "RemoteStartTransaction"
).last
```

### View Message Logs

```ruby
# Get all messages for a charge point
charge_point.messages.order(created_at: :desc).limit(10)

# Get only outbound messages (CS → CP)
charge_point.messages.outbound.recent.limit(5)

# Get only inbound messages (CP → CS)
charge_point.messages.inbound.recent.limit(5)
```

## Next Steps

Now that you have OCPP Rails installed, you can:

### 1. Implement Remote Charging
Follow the [Remote Charging Guide](remote-charging.md) to implement:
- Remote start transactions
- Meter value monitoring
- Remote stop transactions
- Session management

### 2. Configure Advanced Options
See the [Configuration Guide](configuration.md) for:
- Custom charging profiles
- Smart charging settings
- Security options
- Performance tuning

### 3. Integrate with Your Application
Check the [API Reference](api-reference.md) to learn about:
- Model methods and scopes
- Controller actions
- Background jobs
- Helper methods

### 4. Set Up Testing
Review the [Testing Guide](testing.md) to:
- Run the test suite
- Write integration tests
- Test OCPP message flows

## Common Setup Issues

### Redis Connection Error

**Problem:** `Error connecting to Redis on localhost:6379`

**Solution:**
```bash
# Check if Redis is running
redis-cli ping

# If not running, start it
# macOS
brew services start redis

# Linux
sudo systemctl start redis
```

### Migration Errors

**Problem:** `PG::DuplicateTable: ERROR: relation "ocpp_charge_points" already exists`

**Solution:**
```bash
# Rollback and re-run
rails db:rollback STEP=4
rails db:migrate
```

### Route Mounting Issues

**Problem:** Routes not showing up

**Solution:** Check that `config/routes.rb` includes:
```ruby
mount Ocpp::Rails::Engine => '/ocpp_admin'
```

### WebSocket Connection Issues

**Problem:** Charge points can't connect via WebSocket

**Solution:**
1. Verify Redis is running
2. Check `config/cable.yml` configuration
3. Ensure your server supports WebSockets
4. Check firewall settings

## Development vs Production

### Development Environment

```ruby
# config/environments/development.rb
config.action_cable.url = "ws://localhost:3000/cable"
config.action_cable.allowed_request_origins = [
  'http://localhost:3000',
  /http:\/\/localhost*/
]
```

### Production Environment

```ruby
# config/environments/production.rb
config.action_cable.url = "wss://yourdomain.com/cable"
config.action_cable.allowed_request_origins = [
  'https://yourdomain.com',
  'https://www.yourdomain.com'
]
```

Don't forget to set the `REDIS_URL` environment variable in production:

```bash
# Heroku
heroku config:set REDIS_URL=redis://your-redis-url

# Docker
-e REDIS_URL=redis://redis:6379/1

# Railway/Render
# Set via dashboard environment variables
```

## Quick Reference

### Essential Commands

```bash
# Install
bundle install
rails generate ocpp:rails:install
rails db:migrate

# Verify
rails routes | grep ocpp
rails dbconsole

# Run tests
rails test test/ocpp/integration/

# Console
rails console
```

### Essential Models

```ruby
# Charge Points
Ocpp::Rails::ChargePoint.all
Ocpp::Rails::ChargePoint.connected
Ocpp::Rails::ChargePoint.available

# Sessions
Ocpp::Rails::ChargingSession.active
Ocpp::Rails::ChargingSession.completed

# Meter Values
Ocpp::Rails::MeterValue.energy
Ocpp::Rails::MeterValue.power

# Messages
Ocpp::Rails::Message.inbound
Ocpp::Rails::Message.outbound
```

## Getting Help

If you encounter issues:

1. Check the [Troubleshooting Guide](troubleshooting.md)
2. Review the [API Reference](api-reference.md)
3. Search [GitHub Issues](https://github.com/yourusername/ocpp-rails/issues)
4. Ask in [GitHub Discussions](https://github.com/yourusername/ocpp-rails/discussions)

## What's Next?

✅ Installation complete!

Now you're ready to:
- 📖 Read the [Remote Charging Guide](remote-charging.md)
- 🔧 Configure [Advanced Options](configuration.md)
- 💻 Explore the [API Reference](api-reference.md)
- 🧪 Run the [Test Suite](testing.md)

---

**Need help?** See [Troubleshooting](troubleshooting.md) or [open an issue](https://github.com/yourusername/ocpp-rails/issues).

**Ready to code?** Continue to [Remote Charging Guide](remote-charging.md) →