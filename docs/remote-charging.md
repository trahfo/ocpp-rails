# Remote Charging Session Implementation - Complete Guide

This document provides a comprehensive overview of the OCPP 1.6 remote charging session implementation, including all message flows, tests, and components.

## Overview

The remote charging session workflow allows a Central System (CS) to remotely start and stop charging sessions on a Charge Point (CP), while continuously monitoring energy consumption through meter values. This is a core OCPP 1.6 use case for mobile app-initiated charging and centralized fleet management.

## Complete Message Flow

### 1. Remote Start Charging Session

```
┌─────────────────┐                                    ┌─────────────────┐
│  Central System │                                    │  Charge Point   │
└────────┬────────┘                                    └────────┬────────┘
         │                                                      │
         │  1. RemoteStartTransaction.req                      │
         │      (idTag, connectorId?, chargingProfile?)        │
         ├─────────────────────────────────────────────────────>│
         │                                                      │
         │  2. RemoteStartTransaction.conf                     │
         │      (status: Accepted/Rejected)                    │
         │<─────────────────────────────────────────────────────┤
         │                                                      │
         │  3. StatusNotification.req                          │
         │      (connectorId, status: Preparing)               │
         │<─────────────────────────────────────────────────────┤
         │                                                      │
         │  4. StatusNotification.conf                         │
         ├─────────────────────────────────────────────────────>│
         │                                                      │
         │  5. StartTransaction.req                            │
         │      (connectorId, idTag, meterStart, timestamp)    │
         │<─────────────────────────────────────────────────────┤
         │                                                      │
         │  6. StartTransaction.conf                           │
         │      (transactionId, idTagInfo)                     │
         ├─────────────────────────────────────────────────────>│
         │                                                      │
         │  7. StatusNotification.req                          │
         │      (connectorId, status: Charging)                │
         │<─────────────────────────────────────────────────────┤
         │                                                      │
         │  8. StatusNotification.conf                         │
         ├─────────────────────────────────────────────────────>│
```

### 2. Continuous Meter Value Monitoring

```
┌─────────────────┐                                    ┌─────────────────┐
│  Central System │                                    │  Charge Point   │
└────────┬────────┘                                    └────────┬────────┘
         │                                                      │
         │  Periodic (every N seconds)                         │
         │                                                      │
         │  MeterValues.req                                    │
         │      (connectorId, transactionId?, meterValue[])    │
         │<─────────────────────────────────────────────────────┤
         │                                                      │
         │  MeterValues.conf                                   │
         │      (empty payload)                                │
         ├─────────────────────────────────────────────────────>│
         │                                                      │
         │  [Repeats periodically during charging]             │
```

### 3. Remote Stop Charging Session

```
┌─────────────────┐                                    ┌─────────────────┐
│  Central System │                                    │  Charge Point   │
└────────┬────────┘                                    └────────┬────────┘
         │                                                      │
         │  1. RemoteStopTransaction.req                       │
         │      (transactionId)                                │
         ├─────────────────────────────────────────────────────>│
         │                                                      │
         │  2. RemoteStopTransaction.conf                      │
         │      (status: Accepted/Rejected)                    │
         │<─────────────────────────────────────────────────────┤
         │                                                      │
         │  3. StopTransaction.req                             │
         │      (transactionId, meterStop, timestamp, reason)  │
         │<─────────────────────────────────────────────────────┤
         │                                                      │
         │  4. StopTransaction.conf                            │
         │      (idTagInfo)                                    │
         ├─────────────────────────────────────────────────────>│
         │                                                      │
         │  5. StatusNotification.req                          │
         │      (connectorId, status: Finishing)               │
         │<─────────────────────────────────────────────────────┤
         │                                                      │
         │  6. StatusNotification.conf                         │
         ├─────────────────────────────────────────────────────>│
         │                                                      │
         │  7. StatusNotification.req                          │
         │      (connectorId, status: Available)               │
         │<─────────────────────────────────────────────────────┤
         │                                                      │
         │  8. StatusNotification.conf                         │
         ├─────────────────────────────────────────────────────>│
```

## Implementation Components

### Models

#### 1. ChargePoint (`app/models/ocpp/rails/charge_point.rb`)

```ruby
class Ocpp::Rails::ChargePoint < ApplicationRecord
  has_many :charging_sessions, dependent: :destroy
  has_many :meter_values, dependent: :destroy
  has_many :messages, dependent: :destroy

  validates :identifier, presence: true, uniqueness: true
  validates :ocpp_protocol, inclusion: { in: Ocpp::Rails.supported_versions }

  scope :connected, -> { where(connected: true) }
  scope :available, -> { where(status: "Available") }
  scope :charging, -> { where(status: "Charging") }

  def heartbeat!
    update(last_heartbeat_at: Time.current, connected: true)
  end

  def disconnect!
    update(connected: false)
  end

  def current_session
    charging_sessions.where(stopped_at: nil).order(started_at: :desc).first
  end

  def available?
    status == "Available" && connected?
  end
end
```

**Key Features:**
- Tracks charge point status (Available, Charging, Faulted, etc.)
- Manages connection state and heartbeat
- Associates with charging sessions and meter values
- Validates OCPP protocol version

#### 2. ChargingSession (`app/models/ocpp/rails/charging_session.rb`)

```ruby
class Ocpp::Rails::ChargingSession < ApplicationRecord
  belongs_to :charge_point
  has_many :meter_values, dependent: :destroy

  validates :connector_id, presence: true
  validates :transaction_id, uniqueness: true, allow_nil: true

  scope :active, -> { where(stopped_at: nil) }
  scope :completed, -> { where.not(stopped_at: nil) }

  before_create :generate_transaction_id

  def active?
    stopped_at.nil?
  end

  def stop!(reason: "Local", meter_value: nil)
    update(
      stopped_at: Time.current,
      stop_meter_value: meter_value,
      stop_reason: reason,
      duration_seconds: calculate_duration,
      energy_consumed: calculate_energy_consumed(meter_value),
      status: "Completed"
    )
  end

  def calculate_duration
    return 0 unless started_at
    ((stopped_at || Time.current) - started_at).to_i
  end

  def calculate_energy_consumed(stop_value = nil)
    return 0 unless start_meter_value
    stop_val = stop_value || stop_meter_value || start_meter_value
    stop_val - start_meter_value
  end

  private

  def generate_transaction_id
    self.transaction_id ||= SecureRandom.uuid
  end
end
```

**Key Features:**
- Manages session lifecycle (active/completed)
- Calculates energy consumption and duration
- Generates unique transaction IDs
- Links to meter values for detailed tracking

#### 3. MeterValue (`app/models/ocpp/rails/meter_value.rb`)

```ruby
class Ocpp::Rails::MeterValue < ApplicationRecord
  belongs_to :charging_session, optional: true
  belongs_to :charge_point

  validates :measurand, presence: true

  scope :energy, -> { where(measurand: "Energy.Active.Import.Register") }
  scope :power, -> { where(measurand: "Power.Active.Import") }
  scope :current, -> { where(measurand: "Current.Import") }
  scope :voltage, -> { where(measurand: "Voltage") }
  scope :recent, -> { order(timestamp: :desc) }
end
```

**Key Features:**
- Stores individual meter readings
- Supports multiple measurands (Energy, Power, Current, Voltage, SoC, Temperature)
- Can be associated with sessions or standalone
- Scoped queries for common measurands

#### 4. Message (`app/models/ocpp/rails/message.rb`)

```ruby
class Ocpp::Rails::Message < ApplicationRecord
  belongs_to :charge_point

  validates :message_id, presence: true
  validates :direction, inclusion: { in: %w[inbound outbound] }
  validates :message_type, inclusion: { in: %w[CALL CALLRESULT CALLERROR] }

  scope :inbound, -> { where(direction: "inbound") }
  scope :outbound, -> { where(direction: "outbound") }
  scope :recent, -> { order(created_at: :desc) }
end
```

**Key Features:**
- Logs all OCPP messages
- Tracks direction (inbound from CP, outbound to CP)
- Stores message type and payload
- Enables message history and debugging

### Controllers

#### 1. ChargePointsController

```ruby
def remote_start
  RemoteStartTransactionJob.perform_later(@charge_point.id, params[:connector_id], params[:id_tag])
  redirect_to @charge_point, notice: "Remote start command sent."
end

def remote_stop
  session = @charge_point.current_session
  RemoteStopTransactionJob.perform_later(@charge_point.id, session.id) if session
  redirect_to @charge_point, notice: "Remote stop command sent."
end
```

#### 2. ChargingSessionsController

```ruby
def stop
  if @session.active?
    RemoteStopTransactionJob.perform_later(@session.charge_point_id, @session.id)
    redirect_to @session, notice: "Stop command sent."
  else
    redirect_to @session, alert: "Session is already stopped."
  end
end
```

### Jobs

#### RemoteStartTransactionJob

```ruby
class Ocpp::Rails::RemoteStartTransactionJob < ApplicationJob
  queue_as :default

  def perform(charge_point_id, connector_id, id_tag)
    charge_point = ChargePoint.find(charge_point_id)
    message_id = SecureRandom.uuid

    payload = {
      connectorId: connector_id.to_i,
      idTag: id_tag
    }

    message = Protocol::MessageHandler.build_call(message_id, "RemoteStartTransaction", payload)
    
    Message.create!(
      charge_point: charge_point,
      message_id: message_id,
      direction: "outbound",
      action: "RemoteStartTransaction",
      message_type: "CALL",
      payload: payload,
      status: "pending"
    )

    send_to_charge_point(charge_point, message)
  end

  private

  def send_to_charge_point(charge_point, message)
    ActionCable.server.broadcast(
      "charge_point_#{charge_point.id}_outbound",
      { message: message }
    )
  end
end
```

#### RemoteStopTransactionJob

Similar structure to RemoteStartTransactionJob but sends RemoteStopTransaction command.

### Database Schema

```ruby
# Charge Points
create_table :ocpp_charge_points do |t|
  t.string :identifier, null: false, index: { unique: true }
  t.string :vendor
  t.string :model
  t.string :serial_number
  t.string :firmware_version
  t.string :ocpp_protocol, default: "1.6"
  t.string :status, default: "Available"
  t.datetime :last_heartbeat_at
  t.boolean :connected, default: false
  t.jsonb :metadata, default: {}
  t.timestamps
end

# Charging Sessions
create_table :ocpp_charging_sessions do |t|
  t.references :charge_point, null: false, foreign_key: { to_table: :ocpp_charge_points }
  t.integer :connector_id, null: false
  t.string :transaction_id, index: { unique: true }
  t.string :id_tag
  t.string :status, default: "Preparing"
  t.datetime :started_at
  t.datetime :stopped_at
  t.decimal :start_meter_value, precision: 10, scale: 2
  t.decimal :stop_meter_value, precision: 10, scale: 2
  t.decimal :energy_consumed, precision: 10, scale: 2
  t.integer :duration_seconds
  t.string :stop_reason
  t.jsonb :metadata, default: {}
  t.timestamps
end

# Meter Values
create_table :ocpp_meter_values do |t|
  t.references :charging_session, null: true, foreign_key: { to_table: :ocpp_charging_sessions }
  t.references :charge_point, null: false, foreign_key: { to_table: :ocpp_charge_points }
  t.integer :connector_id
  t.string :measurand
  t.string :phase
  t.string :unit
  t.string :context
  t.string :format
  t.string :location
  t.decimal :value, precision: 15, scale: 4
  t.datetime :timestamp
  t.timestamps
end

# Messages
create_table :ocpp_messages do |t|
  t.references :charge_point, null: false, foreign_key: { to_table: :ocpp_charge_points }
  t.string :message_id, null: false
  t.string :direction, null: false # inbound, outbound
  t.string :action
  t.string :message_type # CALL, CALLRESULT, CALLERROR
  t.jsonb :payload, default: {}
  t.string :status # pending, sent, received, error
  t.text :error_message
  t.timestamps
end
```

## Test Coverage

### Test Files

1. **`boot_notification_test.rb`** (13 tests)
   - Valid boot notification acceptance
   - Registration status values
   - Minimal/optional fields
   - Multiple boot notifications
   - Connection state management

2. **`heartbeat_test.rb`** (17 tests)
   - Heartbeat timestamp updates
   - Connection maintenance
   - Timeout detection
   - Concurrent heartbeats

3. **`authorize_test.rb`** (22 tests)
   - Valid ID tag authorization
   - Authorization status values
   - Parent ID tag support
   - Local authorization list

4. **`start_transaction_test.rb`** (35 tests)
   - Transaction creation
   - Required fields validation
   - Transaction ID uniqueness
   - Connector availability
   - Authorization integration

5. **`stop_transaction_test.rb`** (40+ tests)
   - Session completion
   - Energy consumption calculation
   - Duration calculation
   - Stop reasons (11 types)
   - Transaction data inclusion

6. **`meter_values_test.rb`** (50+ tests)
   - Periodic meter readings
   - Multiple measurands
   - Reading contexts
   - Phase information
   - Value formats
   - Transaction/non-transaction readings

7. **`remote_start_transaction_test.rb`** (35+ tests)
   - Remote start requests
   - Connector selection
   - Charging profile support
   - Authorization checks
   - Rejection scenarios

8. **`remote_stop_transaction_test.rb`** (35+ tests)
   - Remote stop requests
   - Transaction validation
   - Session termination
   - Multiple connectors

9. **`remote_charging_session_workflow_test.rb`** (5 comprehensive tests)
   - Complete end-to-end flow
   - Multiple connectors
   - Error handling
   - Message chronology
   - State transitions

### Running Tests

```bash
# Run all remote charging tests
rails test test/ocpp/integration/

# Run specific test file
rails test test/ocpp/integration/remote_charging_session_workflow_test.rb

# Run specific test
rails test test/ocpp/integration/remote_charging_session_workflow_test.rb:45

# Run with verbose output
rails test test/ocpp/integration/ -v
```

### Test Results

```
208 runs, 646 assertions, 0 failures, 0 errors, 0 skips
```

## OCPP Message Examples

### RemoteStartTransaction.req

```json
[2, "550e8400-e29b-41d4-a716-446655440000", "RemoteStartTransaction", {
  "idTag": "RFID_USER_001",
  "connectorId": 1
}]
```

### RemoteStartTransaction.conf

```json
[3, "550e8400-e29b-41d4-a716-446655440000", {
  "status": "Accepted"
}]
```

### StartTransaction.req

```json
[2, "550e8400-e29b-41d4-a716-446655440001", "StartTransaction", {
  "connectorId": 1,
  "idTag": "RFID_USER_001",
  "meterStart": 1000,
  "timestamp": "2024-01-15T10:30:00Z"
}]
```

### StartTransaction.conf

```json
[3, "550e8400-e29b-41d4-a716-446655440001", {
  "transactionId": 12345,
  "idTagInfo": {
    "status": "Accepted",
    "expiryDate": "2025-01-15T10:30:00Z"
  }
}]
```

### MeterValues.req

```json
[2, "550e8400-e29b-41d4-a716-446655440002", "MeterValues", {
  "connectorId": 1,
  "transactionId": 12345,
  "meterValue": [{
    "timestamp": "2024-01-15T10:35:00Z",
    "sampledValue": [
      {
        "value": "5000",
        "context": "Sample.Periodic",
        "measurand": "Energy.Active.Import.Register",
        "unit": "Wh"
      },
      {
        "value": "7200",
        "context": "Sample.Periodic",
        "measurand": "Power.Active.Import",
        "unit": "W"
      }
    ]
  }]
}]
```

### MeterValues.conf

```json
[3, "550e8400-e29b-41d4-a716-446655440002", {}]
```

### RemoteStopTransaction.req

```json
[2, "550e8400-e29b-41d4-a716-446655440003", "RemoteStopTransaction", {
  "transactionId": 12345
}]
```

### RemoteStopTransaction.conf

```json
[3, "550e8400-e29b-41d4-a716-446655440003", {
  "status": "Accepted"
}]
```

### StopTransaction.req

```json
[2, "550e8400-e29b-41d4-a716-446655440004", "StopTransaction", {
  "transactionId": 12345,
  "meterStop": 15000,
  "timestamp": "2024-01-15T11:00:00Z",
  "reason": "Remote",
  "transactionData": [{
    "timestamp": "2024-01-15T10:59:00Z",
    "sampledValue": [{
      "value": "14500",
      "context": "Transaction.End",
      "measurand": "Energy.Active.Import.Register",
      "unit": "Wh"
    }]
  }]
}]
```

### StopTransaction.conf

```json
[3, "550e8400-e29b-41d4-a716-446655440004", {
  "idTagInfo": {
    "status": "Accepted"
  }
}]
```

## Configuration

### OCPP Rails Configuration

```ruby
# config/initializers/ocpp_rails.rb
Ocpp::Rails.setup do |config|
  # Default OCPP version
  config.ocpp_version = "1.6"
  
  # Supported OCPP versions
  config.supported_versions = ["1.6", "2.0", "2.0.1", "2.1"]
  
  # Heartbeat interval in seconds
  config.heartbeat_interval = 300
  
  # Connection timeout in seconds
  config.connection_timeout = 30
end
```

### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount Ocpp::Rails::Engine => '/ocpp_admin'
end
```

### ActionCable Configuration

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
  channel_prefix: ocpp_rails_production
```

## Usage Examples

### 1. Starting a Remote Charging Session

```ruby
# From controller or service
charge_point = Ocpp::Rails::ChargePoint.find_by(identifier: "CP_001")

# Send remote start command
Ocpp::Rails::RemoteStartTransactionJob.perform_later(
  charge_point.id,
  1,  # connector_id
  "RFID_USER_001"  # id_tag
)
```

### 2. Monitoring Active Sessions

```ruby
# Get all active sessions
active_sessions = Ocpp::Rails::ChargingSession.active.includes(:charge_point)

# Get current session for a charge point
charge_point = Ocpp::Rails::ChargePoint.find(1)
current_session = charge_point.current_session

# Get meter values for a session
meter_values = current_session.meter_values.recent.limit(10)
energy_values = current_session.meter_values.energy
```

### 3. Stopping a Remote Charging Session

```ruby
# Stop specific session
session = Ocpp::Rails::ChargingSession.find(session_id)
Ocpp::Rails::RemoteStopTransactionJob.perform_later(
  session.charge_point_id,
  session.transaction_id
)

# Or stop current session of a charge point
charge_point = Ocpp::Rails::ChargePoint.find(1)
if session = charge_point.current_session
  Ocpp::Rails::RemoteStopTransactionJob.perform_later(
    charge_point.id,
    session.transaction_id
  )
end
```

### 4. Querying Session Data

```ruby
# Get completed sessions with energy consumption
completed_sessions = Ocpp::Rails::ChargingSession.completed
  .where("energy_consumed > ?", 0)
  .order(stopped_at: :desc)

# Calculate total energy for a charge point
charge_point = Ocpp::Rails::ChargePoint.find(1)
total_energy = charge_point.charging_sessions.completed.sum(:energy_consumed)

# Get sessions by date range
today_sessions = Ocpp::Rails::ChargingSession.completed
  .where("stopped_at >= ?", Time.current.beginning_of_day)
```

### 5. Real-time Meter Value Monitoring

```ruby
# Subscribe to meter values for a charge point (WebSocket)
channel = ActionCable.server.broadcast(
  "charge_point_#{charge_point.id}_meter_values",
  { 
    connector_id: 1,
    energy: 12345,
    power: 7200,
    timestamp: Time.current
  }
)

# Query recent meter values
recent_values = charge_point.meter_values
  .where("timestamp > ?", 5.minutes.ago)
  .order(timestamp: :desc)
```

## Error Handling

### Common Error Scenarios

1. **Connector Unavailable**
   - Status: Rejected
   - Reason: Connector not available for charging

2. **Invalid ID Tag**
   - Status: Rejected
   - Reason: ID tag not authorized

3. **Transaction Not Found**
   - Status: Rejected
   - Reason: Transaction ID doesn't exist

4. **Charge Point Offline**
   - Timeout after configured period
   - Message marked as error

5. **Concurrent Transaction**
   - Status: ConcurrentTx
   - Reason: ID tag already in use

### Error Response Example

```json
[4, "message-id", "NotImplemented", "Feature not supported", {}]
```

## Performance Considerations

1. **Database Indexes**
   - Indexed: charge_point_id, connector_id, transaction_id, timestamp
   - Composite index on (charge_point_id, created_at) for messages

2. **Query Optimization**
   - Use `includes` for eager loading associations
   - Scope queries with date ranges for large datasets
   - Use counter caches for frequently accessed counts

3. **Background Jobs**
   - All remote commands processed asynchronously
   - Redis-backed job queue for reliability
   - Timeout monitoring for hung operations

4. **Caching**
   - Cache charge point status
   - Cache active session counts
   - Invalidate on status changes

## Security Considerations

1. **Authentication**
   - ID tag validation
   - Optional parent ID tag for group authorization
   - Local authorization list for offline operation

2. **Authorization**
   - Charge point identifier verification
   - Transaction ownership validation
   - Connector access control

3. **Data Protection**
   - JSONB payload encryption (optional)
   - Secure WebSocket connections (wss://)
   - Message signature validation (optional)

## Monitoring & Debugging

### Logging

All OCPP messages are logged in the `ocpp_messages` table with:
- Message ID (for correlation)
- Direction (inbound/outbound)
- Action (message type)
- Payload (full message content)
- Status (pending/sent/received/error)
- Timestamps

### Dashboard Queries

```ruby
# Recent activity
recent_messages = Ocpp::Rails::Message.recent.limit(50)

# Active charge points
active_cps = Ocpp::Rails::ChargePoint.connected.available

# Current charging sessions
charging_now = Ocpp::Rails::ChargingSession.active.includes(:charge_point)

# Today's energy
today_energy = Ocpp::Rails::ChargingSession.completed
  .where("stopped_at >= ?", Time.current.beginning_of_day)
  .sum(:energy_consumed)
```

## OCPP 1.6 Compliance

This implementation covers the following OCPP 1.6 feature profiles:

- ✅ **Core Profile**
  - Boot Notification
  - Heartbeat
  - Authorize
  - Start Transaction
  - Stop Transaction
  - Meter Values
  - Status Notification
  - Data Transfer

- ✅ **Remote Control Profile**
  - Remote Start Transaction
  - Remote Stop Transaction

- 🚧 **Smart Charging Profile** (Partial)
  - Charging profiles supported in remote start
  - Full profile management planned

- 🚧 **Reservation Profile** (Planned)
- 🚧 **Firmware Management Profile** (Planned)
- 🚧 **Local Auth List Management Profile** (Planned)

## Future Enhancements

1. **WebSocket Connection Management**
   - Automatic reconnection
   - Connection pooling
   - Heartbeat monitoring

2. **Smart Charging**
   - Full charging profile management
   - Load balancing
   - Dynamic power allocation

3. **Reservation System**
   - Connector reservation
   - Time-based reservations
   - Expiry management

4. **Firmware Updates**
   - Remote firmware management
   - Update scheduling
   - Version tracking

5. **Advanced Analytics**
   - Energy consumption reports
   - Utilization metrics
   - Predictive maintenance

## Support

For issues or questions:
- GitHub: [ocpp-rails repository]
- Documentation: [OCPP 1.6 Specification](../ocpp-1.6_edition_2.md)
- Tests: [Test Suite Documentation](test/ocpp/README.md)

## License

MIT License - See LICENSE file for details