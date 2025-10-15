# ActionCable with SQLite Configuration

This guide explains how OCPP Rails is configured to work with SQLite out of the box using ActionCable's `:async` adapter, eliminating the need for Redis in development and simple deployments.

## Overview

OCPP Rails uses ActionCable for real-time WebSocket communication between:
- **Charge points** ↔ **OCPP Rails** (OCPP protocol messages)
- **OCPP Rails** ↔ **Your UI** (status updates, meter values, session events)

By default, OCPP Rails uses the **async adapter** which works perfectly with SQLite and requires no additional infrastructure.

---

## Automatic Configuration

OCPP Rails automatically configures ActionCable when the engine loads:

```ruby
# lib/ocpp/rails/engine.rb (already configured)
module Ocpp
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace Ocpp::Rails

      initializer "ocpp_rails.action_cable", before: "actioncable.set_configs" do |app|
        # Automatically use async adapter in development and test
        app.config.action_cable.adapter ||= :async if ::Rails.env.development? || ::Rails.env.test?
      end
    end
  end
end
```

**What this means:**
- ✅ No Redis installation required for development
- ✅ No additional configuration needed
- ✅ Works immediately after `bundle install`
- ✅ Perfect for testing and single-server deployments

---

## Environment-Specific Configuration

### Development Environment

OCPP Rails automatically configures the async adapter, but you can customize it:

```ruby
# config/environments/development.rb
Rails.application.configure do
  # Async adapter (default, set by OCPP Rails)
  config.action_cable.adapter = :async
  
  # WebSocket URL (adjust based on your setup)
  config.action_cable.url = "ws://localhost:3000/ocpp/cable"
  
  # Allowed request origins
  config.action_cable.allowed_request_origins = [
    'http://localhost:3000',
    'http://127.0.0.1:3000',
    /http:\/\/localhost*/
  ]
  
  # Disable request origin check for development (optional, less secure)
  # config.action_cable.disable_request_forgery_protection = true
end
```

### Test Environment

```ruby
# config/environments/test.rb
Rails.application.configure do
  # Use test adapter for tests (in-memory, synchronous)
  config.action_cable.adapter = :test
end
```

### Production Environment

For production, you should use Redis or PostgreSQL for multi-server support:

#### Option 1: Redis (Recommended)

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.action_cable.adapter = :redis
  config.action_cable.url = ENV.fetch("CABLE_URL") { "wss://yourdomain.com/ocpp/cable" }
  config.action_cable.allowed_request_origins = [
    'https://yourdomain.com',
    'https://www.yourdomain.com'
  ]
end
```

Install Redis:
```bash
# Ubuntu/Debian
sudo apt-get install redis-server
sudo systemctl start redis

# macOS
brew install redis
brew services start redis

# Docker
docker run -d -p 6379:6379 redis:alpine
```

Configure Redis URL:
```ruby
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: myapp_production
```

#### Option 2: PostgreSQL

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.action_cable.adapter = :postgresql
  config.action_cable.url = ENV.fetch("CABLE_URL") { "wss://yourdomain.com/ocpp/cable" }
end
```

```ruby
# config/cable.yml
production:
  adapter: postgresql
  channel_prefix: myapp_production
```

---

## Async Adapter: Capabilities and Limitations

### ✅ Suitable For

- **Development** - Perfect for local development
- **Testing** - Works great with test suite
- **Single-server deployments** - Production apps running on one server
- **Low to medium traffic** - Handles typical CPMS workloads well
- **Internal tools** - Company-internal charging management systems

### ❌ Not Suitable For

- **Multi-server deployments** - Can't share WebSocket connections across servers
- **High-availability setups** - Connections lost on server restart
- **Very high traffic** - Limited by single-process concurrency
- **Horizontal scaling** - Can't add more servers without Redis/PostgreSQL

### Performance Characteristics

```
Async Adapter Performance:
- Concurrent connections: ~1000 per process
- Broadcast latency: <10ms
- Memory usage: Low (~10MB baseline)
- Restart behavior: All connections dropped
```

---

## Verifying Your Configuration

### In Rails Console

```ruby
# Check which adapter is configured
Rails.application.config.action_cable.adapter
# => :async (development/test)
# => :redis (production)

# Check ActionCable mount path
Rails.application.routes.url_helpers.cable_path
# => "/ocpp/cable"

# Verify adapter class
ActionCable.server.pubsub.class
# => ActionCable::SubscriptionAdapter::Async
# => ActionCable::SubscriptionAdapter::Redis (if using Redis)

# Test broadcast
ActionCable.server.broadcast("test_channel", { message: "Hello!" })
# => nil (successful broadcast)
```

### Testing WebSocket Connection

Create a simple test charge point connection:

```ruby
# In Rails console
cp = Ocpp::Rails::ChargePoint.create!(
  identifier: "TEST001",
  vendor: "Test Vendor",
  model: "Test Model",
  ocpp_protocol: "1.6"
)

# Simulate a broadcast
ActionCable.server.broadcast(
  "charge_point_#{cp.id}_status",
  { connector_id: 1, status: "Available" }
)
```

---

## WebSocket URL Configuration

### Development URLs

```
HTTP:  ws://localhost:3000/ocpp/cable
HTTPS: wss://localhost:3000/ocpp/cable (if using SSL)
```

### Production URLs

```
Always use WSS (secure WebSocket):
wss://yourdomain.com/ocpp/cable
```

### Charge Point Configuration

Configure your charge points to connect to:

```
Development: ws://your-server-ip:3000/ocpp/cable
Production:  wss://yourdomain.com/ocpp/cable

Example with charge point identifier:
ws://192.168.1.100:3000/ocpp/cable?charge_point_id=CP001
```

---

## Common Issues and Solutions

### Issue 1: "Can't connect to WebSocket"

**Symptoms:**
- Charge points can't connect
- Browser console shows WebSocket errors
- No connection logs in Rails

**Solution:**

Check ActionCable is mounted:
```ruby
# config/routes.rb should include (via engine mount):
mount Ocpp::Rails::Engine => '/ocpp'
# This mounts ActionCable at /ocpp/cable
```

Check firewall/security groups allow WebSocket connections on your port.

Verify allowed origins:
```ruby
# config/environments/development.rb
config.action_cable.allowed_request_origins = ['http://localhost:3000']
```

### Issue 2: "Connection drops immediately"

**Symptoms:**
- Charge point connects then immediately disconnects
- Logs show authentication failures

**Solution:**

Check charge point identifier exists:
```ruby
# The charge point must exist in database
Ocpp::Rails::ChargePoint.find_by(identifier: "CP001")
```

Verify channel subscription logic:
```ruby
# app/channels/ocpp/rails/charge_point_channel.rb
# Should find charge point and accept connection
```

### Issue 3: "No broadcasts received in UI"

**Symptoms:**
- UI subscribes successfully
- No updates appear in real-time
- Data exists in database

**Solution:**

Verify you're listening to the correct channel:
```javascript
// Correct:
stream_from "charge_point_#{charge_point.id}_meter_values"

// Wrong:
stream_from "charge_point_meter_values"  // Missing ID
```

Check ActionCable server is running:
```bash
# Should see ActionCable logs
tail -f log/development.log | grep ActionCable
```

Test broadcast manually:
```ruby
# Rails console
ActionCable.server.broadcast("charge_point_1_meter_values", { test: true })
```

### Issue 4: "Performance issues with many charge points"

**Symptoms:**
- Slow UI updates
- High memory usage
- Connection timeouts

**Solution:**

1. **Switch to Redis** for better performance:
```bash
# Install Redis
brew install redis  # macOS
sudo apt install redis-server  # Ubuntu

# Update config
config.action_cable.adapter = :redis
```

2. **Implement throttling** for meter value broadcasts:
```ruby
# Only broadcast every N seconds
class MeterValuesHandler
  def broadcast_meter_value(meter_value)
    cache_key = "last_broadcast_#{@charge_point.id}"
    last = Rails.cache.read(cache_key)
    
    return if last && last > 5.seconds.ago
    
    ActionCable.server.broadcast(...)
    Rails.cache.write(cache_key, Time.current, expires_in: 10.seconds)
  end
end
```

3. **Use selective subscriptions**:
```javascript
// Subscribe only to charge points currently visible in UI
// Unsubscribe when navigating away
```

---

## Upgrading to Redis (When Needed)

When your application grows and needs Redis:

### Step 1: Install Redis

```bash
# Add redis gem to Gemfile
gem 'redis', '~> 5.0'

# Install
bundle install
```

### Step 2: Configure Cable.yml

```yaml
# config/cable.yml
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

### Step 3: Update Environment Config

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.action_cable.adapter = :redis
  config.action_cable.url = "wss://yourdomain.com/ocpp/cable"
end
```

### Step 4: Set Environment Variable

```bash
# .env or hosting platform
REDIS_URL=redis://localhost:6379/1

# Heroku
heroku config:set REDIS_URL=redis://your-redis-url

# Docker
docker run -e REDIS_URL=redis://redis:6379/1
```

### Step 5: Restart Application

```bash
# Development
bin/rails restart

# Production
# Restart your application server (Puma, Unicorn, etc.)
```

---

## Docker Configuration

If using Docker, here's a complete setup:

```yaml
# docker-compose.yml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - REDIS_URL=redis://redis:6379/1
      - DATABASE_URL=sqlite3:db/production.sqlite3
    depends_on:
      - redis
    volumes:
      - ./db:/app/db
      - ./log:/app/log

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  redis_data:
```

---

## Monitoring ActionCable

### View Active Connections

```ruby
# Rails console
ActionCable.server.connections.size
# => 5 (number of active WebSocket connections)
```

### Monitor Broadcasts

```ruby
# Enable ActionCable logging
Rails.logger.level = :debug

# Watch logs
tail -f log/development.log | grep "ActionCable\|OCPP"
```

### Metrics (Production)

Consider adding monitoring:

```ruby
# config/initializers/action_cable_metrics.rb
if defined?(ActionCable)
  ActiveSupport::Notifications.subscribe('broadcast.action_cable') do |name, start, finish, id, payload|
    duration = finish - start
    Rails.logger.info "ActionCable Broadcast: #{payload[:channel]} (#{duration.round(3)}s)"
    
    # Send to your metrics service (Datadog, New Relic, etc.)
    # StatsD.histogram('actioncable.broadcast.duration', duration)
  end
end
```

---

## Best Practices

### 1. Use Async for Development

```ruby
# config/environments/development.rb
config.action_cable.adapter = :async  # Simple, no infrastructure
```

### 2. Use Redis for Production

```ruby
# config/environments/production.rb
config.action_cable.adapter = :redis  # Scalable, reliable
```

### 3. Secure Your WebSockets

```ruby
# Always use WSS in production
config.action_cable.url = "wss://yourdomain.com/ocpp/cable"

# Limit allowed origins
config.action_cable.allowed_request_origins = ['https://yourdomain.com']
```

### 4. Implement Authentication

```ruby
# Verify charge point identity
class ChargePointChannel < ActionCable::Channel::Base
  def subscribed
    @charge_point = ChargePoint.find_by(identifier: params[:charge_point_id])
    reject unless @charge_point&.valid_auth_token?(params[:token])
  end
end
```

### 5. Handle Disconnections Gracefully

```ruby
# Update charge point status on disconnect
def unsubscribed
  @charge_point&.disconnect!
end
```

---

## Performance Tuning

### Async Adapter Tuning

```ruby
# config/environments/production.rb (if using async)
config.action_cable.worker_pool_size = 4  # Number of worker threads
```

### Redis Tuning

```yaml
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV['REDIS_URL'] %>
  channel_prefix: myapp_production
  timeout: 1  # Connection timeout (seconds)
  reconnect_attempts: 3
```

### Connection Pool

```ruby
# config/puma.rb
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# More workers = more memory but better WebSocket handling
```

---

## Testing

### Test ActionCable in RSpec

```ruby
# spec/channels/charge_point_channel_spec.rb
require 'rails_helper'

RSpec.describe Ocpp::Rails::ChargePointChannel, type: :channel do
  let(:charge_point) { create(:charge_point) }

  it "subscribes successfully with valid charge point" do
    subscribe(charge_point_id: charge_point.identifier)
    expect(subscription).to be_confirmed
  end

  it "rejects subscription with invalid charge point" do
    subscribe(charge_point_id: "INVALID")
    expect(subscription).to be_rejected
  end

  it "broadcasts status updates" do
    subscribe(charge_point_id: charge_point.identifier)
    
    expect {
      ActionCable.server.broadcast(
        "charge_point_#{charge_point.id}_status",
        { status: "Available" }
      )
    }.to have_broadcasted_to(charge_point).from_channel(described_class)
  end
end
```

---

## Troubleshooting Checklist

- [ ] ActionCable is mounted: `mount ActionCable.server => '/cable'`
- [ ] Adapter is configured: `:async` (dev) or `:redis` (prod)
- [ ] Charge point exists in database
- [ ] WebSocket URL is correct (ws:// or wss://)
- [ ] Firewall allows WebSocket connections
- [ ] Allowed origins include your domain
- [ ] Channel subscriptions use correct format
- [ ] Broadcasts use correct channel names
- [ ] Redis is running (if using redis adapter)

---

## Additional Resources

- [ActionCable Overview](https://guides.rubyonrails.org/action_cable_overview.html)
- [Real-Time Monitoring Guide](real-time-monitoring.md)
- [Getting Started](getting-started.md)
- [API Reference](api-reference.md)

---

**Questions or issues?** Check the [troubleshooting guide](troubleshooting.md) or open an issue on GitHub.