# Troubleshooting Guide

Common issues and solutions for OCPP Rails.

**Navigation**: [← Back to Documentation Index](README.md) | [Configuration Guide →](configuration.md)

## Installation Issues

### Generator Fails to Run

**Problem**: `rails generate ocpp:rails:install` fails with "Could not find generator"

**Solution**:
```bash
# Ensure gem is installed
bundle install

# Clear Spring cache
bin/spring stop

# Retry
rails generate ocpp:rails:install
```

### Migration Errors

**Problem**: `PG::DuplicateTable: ERROR: relation "ocpp_charge_points" already exists`

**Solution**:
```bash
# Check migration status
rails db:migrate:status

# Rollback if needed
rails db:rollback STEP=4

# Re-run migrations
rails db:migrate
```

**Problem**: `ActiveRecord::PendingMigrationError`

**Solution**:
```bash
# Run pending migrations
rails db:migrate

# For test environment
rails db:migrate RAILS_ENV=test
```

## Connection Issues

### Redis Connection Failed

**Problem**: `Error connecting to Redis on localhost:6379`

**Solution**:
```bash
# Check if Redis is running
redis-cli ping

# If not running:
# macOS
brew services start redis

# Linux
sudo systemctl start redis

# Docker
docker run -d -p 6379:6379 redis:alpine

# Verify connection
redis-cli
> ping
PONG
```

**Problem**: `Redis::TimeoutError`

**Solution**:
```yaml
# config/cable.yml
development:
  adapter: redis
  url: redis://localhost:6379/1
  timeout: 10  # Increase timeout
  reconnect_attempts: 3
```

### WebSocket Connection Issues

**Problem**: Charge points can't connect via WebSocket

**Solutions**:

1. **Check ActionCable configuration**:
```ruby
# config/environments/development.rb
config.action_cable.url = "ws://localhost:3000/cable"
config.action_cable.allowed_request_origins = ['http://localhost:3000']
```

2. **Verify Redis is running**:
```bash
redis-cli ping
```

3. **Check firewall settings**:
```bash
# Allow WebSocket connections
sudo ufw allow 3000/tcp
```

4. **Test WebSocket endpoint**:
```bash
# Using wscat
npm install -g wscat
wscat -c ws://localhost:3000/cable
```

### Database Connection Issues

**Problem**: `ActiveRecord::ConnectionNotEstablished`

**Solution**:
```bash
# Check database exists
rails db:create

# Check credentials in config/database.yml
# Verify database is running
# PostgreSQL
pg_isready

# MySQL
mysqladmin ping
```

## Runtime Issues

### Messages Not Being Sent

**Problem**: Remote start/stop commands don't reach charge points

**Diagnostic Steps**:

1. **Check message was created**:
```ruby
# Rails console
Ocpp::Rails::Message.where(
  charge_point_id: YOUR_CP_ID,
  action: "RemoteStartTransaction"
).last
```

2. **Verify charge point is connected**:
```ruby
charge_point = Ocpp::Rails::ChargePoint.find(YOUR_CP_ID)
charge_point.connected?  # Should be true
```

3. **Check ActionCable logs**:
```bash
# In development.log or production.log
tail -f log/development.log | grep "ActionCable"
```

4. **Verify background job is running**:
```ruby
# If using Sidekiq
Sidekiq::Queue.new.size  # Should be 0 if jobs are processing

# Check failed jobs
Sidekiq::RetrySet.new.size
```

### Heartbeat Timeout

**Problem**: Charge points showing as disconnected

**Solution**:

1. **Check last heartbeat**:
```ruby
charge_point = Ocpp::Rails::ChargePoint.find(YOUR_CP_ID)
charge_point.last_heartbeat_at
# Should be within heartbeat_interval
```

2. **Adjust heartbeat interval**:
```ruby
# config/initializers/ocpp_rails.rb
Ocpp::Rails.setup do |config|
  config.heartbeat_interval = 600  # 10 minutes (more lenient)
end
```

3. **Implement automatic disconnection check**:
```ruby
# app/jobs/heartbeat_monitor_job.rb
class HeartbeatMonitorJob < ApplicationJob
  def perform
    timeout = Ocpp::Rails.configuration.heartbeat_interval * 2
    threshold = Time.current - timeout.seconds
    
    Ocpp::Rails::ChargePoint.connected.where(
      "last_heartbeat_at < ?", threshold
    ).find_each do |cp|
      cp.disconnect!
    end
  end
end

# Schedule this job every 5 minutes
```

### Transaction ID Mismatch

**Problem**: `StopTransaction` references unknown transaction ID

**Solution**:

1. **Verify session exists**:
```ruby
session = Ocpp::Rails::ChargingSession.find_by(
  transaction_id: "YOUR_TRANSACTION_ID"
)
```

2. **Check for orphaned transactions**:
```ruby
# Find active sessions without transaction_id
Ocpp::Rails::ChargingSession.active.where(transaction_id: nil)

# Generate missing transaction IDs
session.update(transaction_id: SecureRandom.uuid)
```

## Performance Issues

### Slow Queries

**Problem**: Database queries taking too long

**Solution**:

1. **Check missing indexes**:
```sql
-- PostgreSQL
EXPLAIN ANALYZE SELECT * FROM ocpp_messages 
WHERE charge_point_id = 1 ORDER BY created_at DESC LIMIT 10;
```

2. **Add indexes if needed** (already included in migrations):
```ruby
# db/migrate/add_performance_indexes.rb
add_index :ocpp_messages, [:charge_point_id, :created_at]
add_index :ocpp_meter_values, :timestamp
add_index :ocpp_charging_sessions, [:charge_point_id, :connector_id]
```

3. **Use eager loading**:
```ruby
# Bad - N+1 queries
sessions = Ocpp::Rails::ChargingSession.all
sessions.each { |s| puts s.charge_point.identifier }

# Good - eager loading
sessions = Ocpp::Rails::ChargingSession.includes(:charge_point).all
sessions.each { |s| puts s.charge_point.identifier }
```

### Memory Issues

**Problem**: High memory usage

**Solution**:

1. **Batch process large datasets**:
```ruby
# Instead of:
Ocpp::Rails::MeterValue.all.each { |mv| process(mv) }

# Use:
Ocpp::Rails::MeterValue.find_each(batch_size: 100) do |mv|
  process(mv)
end
```

2. **Clean up old data**:
```ruby
# Remove old messages (keep last 30 days)
Ocpp::Rails::Message.where(
  "created_at < ?", 30.days.ago
).delete_all

# Archive completed sessions
Ocpp::Rails::ChargingSession.completed
  .where("stopped_at < ?", 90.days.ago)
  .delete_all
```

## Testing Issues

### Tests Failing

**Problem**: `ActiveRecord::NotNullViolation` in tests

**Solution**:
```bash
# Reset test database
rails db:test:prepare

# Or drop and recreate
rails db:drop db:create db:migrate RAILS_ENV=test
```

**Problem**: Redis connection errors in tests

**Solution**:
```yaml
# config/cable.yml
test:
  adapter: test  # Use test adapter, not Redis
```

**Problem**: Tests timing out

**Solution**:
```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  # Increase test timeout
  self.test_order = :random
  
  # Ensure database is clean between tests
  parallelize(workers: 1) if ENV['PARALLEL_TESTS']
end
```

## Data Issues

### Incorrect Energy Calculations

**Problem**: Energy consumed is negative or incorrect

**Diagnostic**:
```ruby
session = Ocpp::Rails::ChargingSession.find(SESSION_ID)
puts "Start: #{session.start_meter_value}"
puts "Stop: #{session.stop_meter_value}"
puts "Consumed: #{session.energy_consumed}"

# Recalculate manually
expected = session.stop_meter_value - session.start_meter_value
puts "Expected: #{expected}"
```

**Solution**:
```ruby
# Recalculate energy for a session
session.update(
  energy_consumed: session.calculate_energy_consumed(session.stop_meter_value)
)

# Fix all sessions
Ocpp::Rails::ChargingSession.completed.find_each do |session|
  next unless session.start_meter_value && session.stop_meter_value
  
  correct_energy = session.stop_meter_value - session.start_meter_value
  if session.energy_consumed != correct_energy
    session.update(energy_consumed: correct_energy)
  end
end
```

### Missing Meter Values

**Problem**: No meter values recorded during session

**Check**:
```ruby
session = Ocpp::Rails::ChargingSession.find(SESSION_ID)
session.meter_values.count  # Should be > 0

# Check messages
session.charge_point.messages.where(action: "MeterValues").recent.limit(10)
```

**Solution**:
- Verify charge point is sending meter values
- Check MeterValues messages are being received
- Verify charging_session_id is being set correctly

## Configuration Issues

### Invalid OCPP Version

**Problem**: Charge point rejected due to version mismatch

**Solution**:
```ruby
# config/initializers/ocpp_rails.rb
Ocpp::Rails.setup do |config|
  # Add the charge point's version
  config.supported_versions = ["1.6", "2.0", "2.0.1"]
end

# Restart server
```

### Routes Not Working

**Problem**: 404 error when accessing `/ocpp_admin`

**Check**:
```bash
# Verify engine is mounted
rails routes | grep ocpp

# Should show:
# ocpp_admin     /ocpp_admin     Ocpp::Rails::Engine
```

**Solution**:
```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount Ocpp::Rails::Engine => '/ocpp_admin'
end
```

## Debugging Tips

### Enable Verbose Logging

```ruby
# config/environments/development.rb
config.log_level = :debug

# For OCPP messages specifically
Rails.logger.debug "OCPP Message: #{message.inspect}"
```

### Inspect Message Payloads

```ruby
# Rails console
message = Ocpp::Rails::Message.last
puts JSON.pretty_generate(message.payload)
```

### Check Background Jobs

```ruby
# If using Sidekiq
# View queue
Sidekiq::Queue.new.size

# View scheduled jobs
Sidekiq::ScheduledSet.new.size

# View failed jobs
Sidekiq::RetrySet.new.each do |job|
  puts job.item
end
```

### Monitor WebSocket Connections

```ruby
# config/initializers/action_cable.rb
ActionCable.server.config.logger = Logger.new(STDOUT)

# Check active connections
ActionCable.server.connections.size
```

## Common Error Messages

### `Ocpp::Rails::ChargePoint not found`

**Cause**: Invalid charge point ID

**Solution**: Verify charge point exists
```ruby
Ocpp::Rails::ChargePoint.exists?(id: YOUR_ID)
```

### `Transaction already stopped`

**Cause**: Attempting to stop an already completed session

**Solution**: Check session status before stopping
```ruby
session = Ocpp::Rails::ChargingSession.find(SESSION_ID)
if session.active?
  session.stop!(meter_value: final_value)
end
```

### `Connector not available`

**Cause**: Trying to start transaction on busy/faulted connector

**Solution**: Check charge point status
```ruby
charge_point = Ocpp::Rails::ChargePoint.find(CP_ID)
puts charge_point.status  # Should be "Available"
puts charge_point.connected?  # Should be true
```

## Getting Help

If you can't resolve your issue:

1. **Check the logs**: `log/development.log` or `log/production.log`
2. **Enable debug logging**: See "Enable Verbose Logging" above
3. **Search existing issues**: [GitHub Issues](https://github.com/trahfo/ocpp-rails/issues)
4. **Ask for help**: [GitHub Discussions](https://github.com/trahfo/ocpp-rails/discussions)
5. **Review documentation**: 
   - [Getting Started Guide](getting-started.md)
   - [Configuration Guide](configuration.md)
   - [API Reference](api-reference.md)

### Providing Debug Information

When reporting issues, include:

```bash
# System info
ruby -v
rails -v
redis-cli --version

# Gem version
bundle show ocpp-rails

# Database adapter
rails runner "puts ActiveRecord::Base.connection.adapter_name"

# Redis connection test
rails runner "puts ActionCable.server.pubsub.redis_connection_for_subscriptions.ping"

# Recent logs
tail -n 100 log/development.log

# Migration status
rails db:migrate:status | grep ocpp
```

---

**Next**: [Remote Charging Guide](remote-charging.md) →  
**Back**: [Testing Guide](testing.md) ←