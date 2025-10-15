# Configuration Guide

Complete reference for configuring OCPP Rails in your application.

## Basic Configuration

### Initializer Configuration

The main configuration is in `config/initializers/ocpp_rails.rb`:

```ruby
Ocpp::Rails.setup do |config|
  # OCPP protocol version
  config.ocpp_version = "1.6"
  
  # Supported OCPP versions
  config.supported_versions = ["1.6", "2.0", "2.0.1", "2.1"]
  
  # Heartbeat interval (seconds)
  config.heartbeat_interval = 300
  
  # Connection timeout (seconds)
  config.connection_timeout = 30
end
```

## Configuration Options

### OCPP Version Settings

#### `ocpp_version`
- **Type**: String
- **Default**: `"1.6"`
- **Description**: Default OCPP protocol version to use
- **Valid Values**: `"1.6"`, `"2.0"`, `"2.0.1"`, `"2.1"`

```ruby
config.ocpp_version = "1.6"
```

#### `supported_versions`
- **Type**: Array of Strings
- **Default**: `["1.6", "2.0", "2.0.1", "2.1"]`
- **Description**: List of OCPP versions your system supports
- **Note**: Charge points will validate against this list during boot

```ruby
config.supported_versions = ["1.6", "2.0", "2.0.1"]
```

### Connection Settings

#### `heartbeat_interval`
- **Type**: Integer
- **Default**: `300` (5 minutes)
- **Unit**: Seconds
- **Description**: How often charge points should send heartbeat messages
- **Range**: 30-3600 (30 seconds to 1 hour recommended)

```ruby
config.heartbeat_interval = 300  # 5 minutes
```

**Considerations:**
- Lower values: More frequent updates, more network traffic
- Higher values: Less traffic, slower fault detection
- Recommended: 300-600 seconds for production

#### `connection_timeout`
- **Type**: Integer
- **Default**: `30`
- **Unit**: Seconds
- **Description**: Timeout for charge point responses
- **Range**: 10-120 seconds

```ruby
config.connection_timeout = 30
```

## Environment-Specific Configuration

### Development

```ruby
# config/environments/development.rb
Rails.application.configure do
  # ActionCable
  config.action_cable.url = "ws://localhost:3000/cable"
  config.action_cable.allowed_request_origins = [
    'http://localhost:3000',
    /http:\/\/localhost*/
  ]
  
  # Eager loading for development
  config.eager_load = false
end
```

### Test

```ruby
# config/environments/test.rb
Rails.application.configure do
  # Use test adapter for ActionCable
  config.action_cable.adapter = :test
  
  # Eager load for tests
  config.eager_load = true
end
```

### Production

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Secure WebSocket
  config.action_cable.url = "wss://yourdomain.com/cable"
  
  # Allowed origins
  config.action_cable.allowed_request_origins = [
    'https://yourdomain.com',
    'https://www.yourdomain.com'
  ]
  
  # Mount path
  config.action_cable.mount_path = '/cable'
  
  # Eager load
  config.eager_load = true
end
```

## Redis Configuration

### Basic Redis Setup

Edit `config/cable.yml`:

```yaml
development:
  adapter: redis
  url: redis://localhost:6379/1
  channel_prefix: myapp_development

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: myapp_production
```

### Redis with Password

```yaml
production:
  adapter: redis
  url: redis://:password@hostname:6379/1
  channel_prefix: myapp_production
```

### Redis Sentinel

```yaml
production:
  adapter: redis
  url: redis://sentinel1:26379,sentinel2:26379,sentinel3:26379/mymaster
  sentinels:
    - host: sentinel1
      port: 26379
    - host: sentinel2
      port: 26379
    - host: sentinel3
      port: 26379
  channel_prefix: myapp_production
```

### Redis Cluster

```yaml
production:
  adapter: redis
  cluster:
    - redis://node1:6379/1
    - redis://node2:6379/1
    - redis://node3:6379/1
  channel_prefix: myapp_production
```

## Database Configuration

### PostgreSQL (Recommended for Production)

```yaml
# config/database.yml
production:
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  host: <%= ENV['DATABASE_HOST'] %>
  database: <%= ENV['DATABASE_NAME'] %>
  username: <%= ENV['DATABASE_USER'] %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
```

**Optimizations:**
```ruby
# config/initializers/database.rb
ActiveRecord::Base.connection.execute("SET TIME ZONE 'UTC'")

# Add indexes for performance
# Already included in migrations:
# - charge_point_id on all related tables
# - message_id on messages
# - timestamp on meter_values
```

### MySQL

```yaml
production:
  adapter: mysql2
  encoding: utf8mb4
  collation: utf8mb4_unicode_ci
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  host: <%= ENV['DATABASE_HOST'] %>
  database: <%= ENV['DATABASE_NAME'] %>
  username: <%= ENV['DATABASE_USER'] %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
```

## Routes Configuration

### Default Mounting

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount Ocpp::Rails::Engine => '/ocpp_admin'
end
```

### Custom Path

```ruby
# Mount at custom path
mount Ocpp::Rails::Engine => '/charging'

# With subdomain
constraints subdomain: 'ocpp' do
  mount Ocpp::Rails::Engine => '/'
end

# With namespace
namespace :api do
  mount Ocpp::Rails::Engine => '/ocpp'
end
```

## Security Configuration

### Authentication

Add authentication to OCPP routes:

```ruby
# config/routes.rb
authenticate :user, ->(user) { user.admin? } do
  mount Ocpp::Rails::Engine => '/ocpp_admin'
end
```

### CORS Configuration

For API access:

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://yourdomain.com'
    resource '/ocpp_admin/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options]
  end
end
```

### SSL/TLS

Always use HTTPS in production:

```ruby
# config/environments/production.rb
config.force_ssl = true
config.ssl_options = {
  redirect: {
    exclude: ->(request) { request.path =~ /health/ }
  }
}
```

## Performance Configuration

### Connection Pooling

```ruby
# config/database.yml
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 25 } %>
  
# config/puma.rb
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

workers ENV.fetch("WEB_CONCURRENCY") { 2 }
```

### Background Jobs

Configure Sidekiq or ActiveJob:

```ruby
# config/initializers/active_job.rb
Rails.application.config.active_job.queue_adapter = :sidekiq

# config/sidekiq.yml
:concurrency: 10
:queues:
  - default
  - ocpp
  - mailers
```

### Caching

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/2" },
  namespace: 'myapp',
  expires_in: 1.hour
}
```

## Logging Configuration

### Custom Log Levels

```ruby
# config/environments/production.rb
config.log_level = :info

# Separate OCPP logs
config.logger = ActiveSupport::TaggedLogging.new(
  Logger.new("#{Rails.root}/log/#{Rails.env}.log")
)
```

### Log Rotation

```ruby
# config/application.rb
config.logger = ActiveSupport::Logger.new(
  "#{Rails.root}/log/#{Rails.env}.log",
  10,           # Keep 10 old files
  10.megabytes  # Max 10MB per file
)
```

### Structured Logging

```ruby
# config/initializers/lograge.rb
Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.custom_options = lambda do |event|
    {
      charge_point_id: event.payload[:charge_point_id],
      action: event.payload[:ocpp_action],
      message_id: event.payload[:message_id]
    }
  end
end
```

## Monitoring Configuration

### Health Check Endpoint

```ruby
# config/routes.rb
get '/health', to: proc { [200, {}, ['OK']] }

# With detailed check
get '/health/detailed', to: 'health#show'

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def show
    checks = {
      database: check_database,
      redis: check_redis,
      charge_points: check_charge_points
    }
    
    status = checks.values.all? ? 200 : 503
    render json: checks, status: status
  end
  
  private
  
  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    'OK'
  rescue => e
    e.message
  end
  
  def check_redis
    Redis.current.ping == 'PONG' ? 'OK' : 'Error'
  rescue => e
    e.message
  end
  
  def check_charge_points
    Ocpp::Rails::ChargePoint.connected.count > 0 ? 'OK' : 'No connected CPs'
  rescue => e
    e.message
  end
end
```

## Environment Variables

### Required Variables

```bash
# .env.production
DATABASE_URL=postgresql://user:pass@host:5432/dbname
REDIS_URL=redis://redis-host:6379/1
SECRET_KEY_BASE=your-secret-key-base
RAILS_ENV=production
```

### Optional Variables

```bash
# OCPP Configuration
OCPP_VERSION=1.6
OCPP_HEARTBEAT_INTERVAL=300
OCPP_CONNECTION_TIMEOUT=30

# Redis
REDIS_TIMEOUT=5
REDIS_RECONNECT_ATTEMPTS=3

# Performance
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2

# Monitoring
SENTRY_DSN=https://your-sentry-dsn
```

## Advanced Configuration

### Custom Message Handler

```ruby
# config/initializers/ocpp_rails.rb
Ocpp::Rails.setup do |config|
  config.message_handler = ->(message) {
    # Custom message processing
    Rails.logger.info "OCPP Message: #{message.action}"
    
    # Call external API, webhook, etc.
    WebhookService.notify(message) if message.action == "StartTransaction"
  }
end
```

### Custom Validators

```ruby
# app/validators/charge_point_validator.rb
class ChargePointValidator < ActiveModel::Validator
  def validate(record)
    if record.identifier.blank?
      record.errors.add(:identifier, "must be present")
    end
    
    if record.ocpp_protocol == "1.6" && record.vendor.blank?
      record.errors.add(:vendor, "required for OCPP 1.6")
    end
  end
end

# In model
class Ocpp::Rails::ChargePoint
  validates_with ChargePointValidator
end
```

## Docker Configuration

### docker-compose.yml

```yaml
version: '3.8'

services:
  app:
    build: .
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/ocpp_production
      - REDIS_URL=redis://redis:6379/1
    depends_on:
      - db
      - redis
    ports:
      - "3000:3000"

  db:
    image: postgres:14-alpine
    environment:
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

## Troubleshooting Configuration Issues

### Check Current Configuration

```ruby
# Rails console
Ocpp::Rails.configuration.ocpp_version
# => "1.6"

Ocpp::Rails.configuration.heartbeat_interval
# => 300
```

### Verify Redis Connection

```ruby
# Rails console
ActionCable.server.pubsub.redis_connection_for_subscriptions.ping
# => "PONG"
```

### Check Database Configuration

```ruby
# Rails console
ActiveRecord::Base.connection.execute("SELECT version()")
```

## Best Practices

1. **Use Environment Variables** for sensitive data
2. **Enable SSL/TLS** in production
3. **Configure proper logging** with rotation
4. **Set up monitoring** and health checks
5. **Use connection pooling** appropriately
6. **Configure Redis persistence** for production
7. **Set up backups** for database
8. **Monitor performance** metrics
9. **Use proper timeouts** to prevent hanging connections
10. **Test configuration** in staging before production

---

**Next**: [API Reference](api-reference.md) →  
**Back**: [Getting Started](getting-started.md) ←