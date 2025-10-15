# API Reference

Complete reference for OCPP Rails models, controllers, jobs, and helpers.

**Navigation**: [← Back to Documentation Index](README.md) | [Message Reference →](message-reference.md)

## Table of Contents

- [Models](#models)
  - [ChargePoint](#chargepoint)
  - [ChargingSession](#chargingsession)
  - [MeterValue](#metervalue)
  - [Message](#message)
- [Controllers](#controllers)
  - [ChargePointsController](#chargepointscontroller)
  - [ChargingSessionsController](#chargingsessionscontroller)
- [Jobs](#jobs)
  - [RemoteStartTransactionJob](#remotestarttransactionjob)
  - [RemoteStopTransactionJob](#remotestoptransactionjob)
- [Configuration](#configuration)
- [Database Schema](#database-schema)

## Models

### ChargePoint

Represents a physical EV charging station.

**Location**: `app/models/ocpp/rails/charge_point.rb`

#### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `identifier` | String | Unique charge point identifier (required, indexed) |
| `vendor` | String | Manufacturer/vendor name |
| `model` | String | Charge point model |
| `serial_number` | String | Hardware serial number |
| `firmware_version` | String | Current firmware version |
| `iccid` | String | SIM card ICCID |
| `imsi` | String | SIM card IMSI |
| `meter_type` | String | Type of energy meter |
| `meter_serial_number` | String | Meter serial number |
| `ocpp_protocol` | String | OCPP protocol version (default: "1.6") |
| `status` | String | Current status (default: "Available") |
| `last_heartbeat_at` | DateTime | Last heartbeat timestamp |
| `connected` | Boolean | Connection state (default: false) |
| `metadata` | JSONB | Additional data (default: {}) |

#### Associations

```ruby
has_many :charging_sessions, dependent: :destroy
has_many :meter_values, dependent: :destroy
has_many :messages, dependent: :destroy
```

#### Validations

```ruby
validates :identifier, presence: true, uniqueness: true
validates :ocpp_protocol, inclusion: { in: Ocpp::Rails.supported_versions }
```

#### Scopes

```ruby
# Connected charge points
Ocpp::Rails::ChargePoint.connected
# => WHERE connected = true

# Available charge points
Ocpp::Rails::ChargePoint.available
# => WHERE status = 'Available'

# Charging charge points
Ocpp::Rails::ChargePoint.charging
# => WHERE status = 'Charging'
```

#### Instance Methods

##### `heartbeat!`

Updates last heartbeat timestamp and marks as connected.

```ruby
charge_point.heartbeat!
# Sets last_heartbeat_at to current time
# Sets connected to true
```

##### `disconnect!`

Marks charge point as disconnected.

```ruby
charge_point.disconnect!
# Sets connected to false
```

##### `current_session`

Returns the active charging session if any.

```ruby
session = charge_point.current_session
# Returns ChargingSession where stopped_at is nil
# Returns nil if no active session
```

##### `available?`

Checks if charge point is available for charging.

```ruby
charge_point.available?
# Returns true if status == "Available" && connected == true
```

#### Example Usage

```ruby
# Create a charge point
cp = Ocpp::Rails::ChargePoint.create!(
  identifier: "CP_001",
  vendor: "ABB",
  model: "Terra 54",
  ocpp_protocol: "1.6",
  status: "Available"
)

# Update heartbeat
cp.heartbeat!

# Check status
cp.available?  # => true

# Get current session
session = cp.current_session

# Query charge points
connected_cps = Ocpp::Rails::ChargePoint.connected.count
available_cps = Ocpp::Rails::ChargePoint.available
```

---

### ChargingSession

Represents a charging transaction/session.

**Location**: `app/models/ocpp/rails/charging_session.rb`

#### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `charge_point_id` | Integer | Foreign key to charge_points (required) |
| `connector_id` | Integer | Connector number (required) |
| `transaction_id` | String | Unique transaction ID (auto-generated) |
| `id_tag` | String | RFID/ID tag used |
| `status` | String | Session status (default: "Preparing") |
| `started_at` | DateTime | Session start time |
| `stopped_at` | DateTime | Session stop time |
| `start_meter_value` | Decimal | Meter value at start (Wh) |
| `stop_meter_value` | Decimal | Meter value at stop (Wh) |
| `energy_consumed` | Decimal | Total energy consumed (Wh) |
| `duration_seconds` | Integer | Session duration in seconds |
| `stop_reason` | String | Reason for stopping |
| `metadata` | JSONB | Additional data (default: {}) |

#### Associations

```ruby
belongs_to :charge_point
has_many :meter_values, dependent: :destroy
```

#### Validations

```ruby
validates :connector_id, presence: true
validates :transaction_id, uniqueness: true, allow_nil: true
```

#### Scopes

```ruby
# Active sessions (not stopped)
Ocpp::Rails::ChargingSession.active
# => WHERE stopped_at IS NULL

# Completed sessions
Ocpp::Rails::ChargingSession.completed
# => WHERE stopped_at IS NOT NULL
```

#### Callbacks

```ruby
before_create :generate_transaction_id
```

#### Instance Methods

##### `active?`

Returns true if session is still active.

```ruby
session.active?
# Returns true if stopped_at is nil
```

##### `stop!(reason: "Local", meter_value: nil)`

Stops the charging session.

```ruby
session.stop!(
  reason: "Remote",
  meter_value: 15000
)

# Updates:
# - stopped_at to current time
# - stop_meter_value to provided value
# - stop_reason to provided reason
# - duration_seconds (calculated)
# - energy_consumed (calculated)
# - status to "Completed"
```

**Parameters:**
- `reason` (String): Stop reason (default: "Local")
- `meter_value` (Integer): Final meter reading in Wh

**Valid Stop Reasons:**
- `Local` - Stopped at charge point
- `Remote` - Stopped by central system
- `EmergencyStop` - Emergency stop activated
- `EVDisconnected` - EV cable disconnected
- `HardReset` - Charge point hard reset
- `PowerLoss` - Loss of power
- `Reboot` - Charge point reboot
- `SoftReset` - Charge point soft reset
- `UnlockCommand` - Unlock command received
- `DeAuthorized` - ID tag deauthorized
- `Other` - Other reason

##### `calculate_duration`

Calculates session duration in seconds.

```ruby
duration = session.calculate_duration
# Returns seconds between started_at and (stopped_at || current time)
```

##### `calculate_energy_consumed(stop_value = nil)`

Calculates total energy consumed.

```ruby
energy = session.calculate_energy_consumed(15000)
# Returns stop_value - start_meter_value
```

#### Example Usage

```ruby
# Create a session
session = charge_point.charging_sessions.create!(
  connector_id: 1,
  id_tag: "RFID_001",
  started_at: Time.current,
  start_meter_value: 1000
)

# Check if active
session.active?  # => true

# Access meter values
session.meter_values.recent.limit(10)

# Stop the session
session.stop!(
  reason: "Remote",
  meter_value: 15000
)

# View results
session.energy_consumed  # => 14000 (Wh = 14 kWh)
session.duration_seconds  # => 3600 (1 hour)
session.stop_reason      # => "Remote"

# Query sessions
active = Ocpp::Rails::ChargingSession.active.count
completed = Ocpp::Rails::ChargingSession.completed
  .where("stopped_at >= ?", 1.day.ago)
```

---

### MeterValue

Stores individual meter readings during charging.

**Location**: `app/models/ocpp/rails/meter_value.rb`

#### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `charging_session_id` | Integer | Foreign key to charging_sessions (nullable) |
| `charge_point_id` | Integer | Foreign key to charge_points (required) |
| `connector_id` | Integer | Connector number |
| `measurand` | String | Type of measurement (required) |
| `phase` | String | Phase (L1, L2, L3, N) |
| `unit` | String | Unit of measurement |
| `context` | String | Reading context |
| `format` | String | Value format (Raw, SignedData) |
| `location` | String | Measurement location |
| `value` | Decimal | Measured value |
| `timestamp` | DateTime | Reading timestamp |

#### Associations

```ruby
belongs_to :charging_session, optional: true
belongs_to :charge_point
```

#### Validations

```ruby
validates :measurand, presence: true
```

#### Scopes

```ruby
# Energy readings
Ocpp::Rails::MeterValue.energy
# => WHERE measurand = 'Energy.Active.Import.Register'

# Power readings
Ocpp::Rails::MeterValue.power
# => WHERE measurand = 'Power.Active.Import'

# Current readings
Ocpp::Rails::MeterValue.current
# => WHERE measurand = 'Current.Import'

# Voltage readings
Ocpp::Rails::MeterValue.voltage
# => WHERE measurand = 'Voltage'

# Recent readings (by timestamp)
Ocpp::Rails::MeterValue.recent
# => ORDER BY timestamp DESC
```

#### Supported Measurands

- `Energy.Active.Import.Register` - Total imported energy (Wh)
- `Energy.Active.Export.Register` - Total exported energy (Wh)
- `Power.Active.Import` - Instantaneous power (W)
- `Power.Active.Export` - Exported power (W)
- `Current.Import` - Current (A)
- `Current.Export` - Exported current (A)
- `Voltage` - Voltage (V)
- `SoC` - State of Charge (%)
- `Temperature` - Temperature (°C)
- `Frequency` - Frequency (Hz)
- And 12+ more OCPP 1.6 measurands

#### Example Usage

```ruby
# Create meter value
mv = session.meter_values.create!(
  connector_id: 1,
  measurand: "Energy.Active.Import.Register",
  value: 12345,
  unit: "Wh",
  context: "Sample.Periodic",
  timestamp: Time.current
)

# Query meter values
energy_values = session.meter_values.energy
power_values = session.meter_values.power
recent = charge_point.meter_values.recent.limit(20)

# Calculate averages
avg_power = session.meter_values.power.average(:value)

# Track energy progression
energy_readings = session.meter_values.energy
  .order(timestamp: :asc)
  .pluck(:timestamp, :value)
```

---

### Message

Logs all OCPP messages for auditing and debugging.

**Location**: `app/models/ocpp/rails/message.rb`

#### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `charge_point_id` | Integer | Foreign key to charge_points (required) |
| `message_id` | String | OCPP message ID (required) |
| `direction` | String | "inbound" or "outbound" (required) |
| `action` | String | OCPP action name |
| `message_type` | String | "CALL", "CALLRESULT", or "CALLERROR" (required) |
| `payload` | JSONB | Message payload (default: {}) |
| `status` | String | Message status |
| `error_message` | Text | Error description if failed |

#### Associations

```ruby
belongs_to :charge_point
```

#### Validations

```ruby
validates :message_id, presence: true
validates :direction, inclusion: { in: %w[inbound outbound] }
validates :message_type, inclusion: { in: %w[CALL CALLRESULT CALLERROR] }
```

#### Scopes

```ruby
# Inbound messages (CP → CS)
Ocpp::Rails::Message.inbound
# => WHERE direction = 'inbound'

# Outbound messages (CS → CP)
Ocpp::Rails::Message.outbound
# => WHERE direction = 'outbound'

# Recent messages
Ocpp::Rails::Message.recent
# => ORDER BY created_at DESC
```

#### Message Statuses

- `pending` - Queued for sending
- `sent` - Sent to charge point
- `received` - Received from charge point
- `error` - Error occurred

#### Example Usage

```ruby
# Create message
msg = charge_point.messages.create!(
  message_id: SecureRandom.uuid,
  direction: "outbound",
  action: "RemoteStartTransaction",
  message_type: "CALL",
  payload: {
    connectorId: 1,
    idTag: "RFID_001"
  },
  status: "pending"
)

# Query messages
recent = charge_point.messages.recent.limit(10)
outbound = charge_point.messages.outbound
start_messages = charge_point.messages.where(action: "StartTransaction")

# View payload
puts JSON.pretty_generate(msg.payload)
```

---

## Controllers

### ChargePointsController

Manages charge point CRUD operations and remote commands.

**Location**: `app/controllers/ocpp/rails/charge_points_controller.rb`

#### Actions

##### `index`
Lists all charge points.

```ruby
GET /ocpp_admin/charge_points
```

##### `show`
Shows charge point details with sessions and meter values.

```ruby
GET /ocpp_admin/charge_points/:id
```

##### `new` / `create`
Creates a new charge point.

```ruby
GET  /ocpp_admin/charge_points/new
POST /ocpp_admin/charge_points
```

##### `edit` / `update`
Updates charge point.

```ruby
GET   /ocpp_admin/charge_points/:id/edit
PATCH /ocpp_admin/charge_points/:id
```

##### `destroy`
Deletes charge point and associated data.

```ruby
DELETE /ocpp_admin/charge_points/:id
```

##### `remote_start`
Sends remote start transaction command.

```ruby
POST /ocpp_admin/charge_points/:id/remote_start

Parameters:
  - connector_id (required)
  - id_tag (required)
```

##### `remote_stop`
Sends remote stop transaction command.

```ruby
POST /ocpp_admin/charge_points/:id/remote_stop
```

---

### ChargingSessionsController

Manages charging sessions.

**Location**: `app/controllers/ocpp/rails/charging_sessions_controller.rb`

#### Actions

##### `index`
Lists all charging sessions with pagination.

```ruby
GET /ocpp_admin/charging_sessions?page=1
```

##### `show`
Shows session details with meter values.

```ruby
GET /ocpp_admin/charging_sessions/:id
```

##### `stop`
Sends stop command for session.

```ruby
POST /ocpp_admin/charging_sessions/:id/stop
```

---

## Jobs

### RemoteStartTransactionJob

Sends remote start transaction command via ActionCable.

**Location**: `app/jobs/ocpp/rails/remote_start_transaction_job.rb`

#### Usage

```ruby
Ocpp::Rails::RemoteStartTransactionJob.perform_later(
  charge_point_id,  # Integer
  connector_id,     # Integer
  id_tag           # String
)
```

#### Example

```ruby
# Immediate execution
Ocpp::Rails::RemoteStartTransactionJob.perform_now(1, 1, "RFID_001")

# Delayed execution
Ocpp::Rails::RemoteStartTransactionJob.perform_later(1, 1, "RFID_001")

# Scheduled execution
Ocpp::Rails::RemoteStartTransactionJob.set(wait: 5.minutes)
  .perform_later(1, 1, "RFID_001")
```

---

### RemoteStopTransactionJob

Sends remote stop transaction command via ActionCable.

**Location**: `app/jobs/ocpp/rails/remote_stop_transaction_job.rb`

#### Usage

```ruby
Ocpp::Rails::RemoteStopTransactionJob.perform_later(
  charge_point_id,  # Integer
  transaction_id    # String
)
```

#### Example

```ruby
# Immediate execution
Ocpp::Rails::RemoteStopTransactionJob.perform_now(1, "tx_123")

# Delayed execution
Ocpp::Rails::RemoteStopTransactionJob.perform_later(1, "tx_123")
```

---

## Configuration

### Ocpp::Rails.setup

Configure OCPP Rails settings.

```ruby
# config/initializers/ocpp_rails.rb
Ocpp::Rails.setup do |config|
  config.ocpp_version = "1.6"
  config.supported_versions = ["1.6", "2.0", "2.0.1", "2.1"]
  config.heartbeat_interval = 300
  config.connection_timeout = 30
end
```

### Ocpp::Rails.configuration

Access current configuration.

```ruby
Ocpp::Rails.configuration.ocpp_version
# => "1.6"

Ocpp::Rails.configuration.heartbeat_interval
# => 300
```

### Ocpp::Rails.supported_versions

Returns array of supported OCPP versions.

```ruby
Ocpp::Rails.supported_versions
# => ["1.6", "2.0", "2.0.1", "2.1"]
```

---

## Database Schema

### ocpp_charge_points

```sql
CREATE TABLE ocpp_charge_points (
  id BIGINT PRIMARY KEY,
  identifier VARCHAR UNIQUE NOT NULL,
  vendor VARCHAR,
  model VARCHAR,
  serial_number VARCHAR,
  firmware_version VARCHAR,
  iccid VARCHAR,
  imsi VARCHAR,
  meter_type VARCHAR,
  meter_serial_number VARCHAR,
  ocpp_protocol VARCHAR DEFAULT '1.6',
  status VARCHAR DEFAULT 'Available',
  last_heartbeat_at TIMESTAMP,
  connected BOOLEAN DEFAULT FALSE,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX idx_cp_identifier ON ocpp_charge_points(identifier);
```

### ocpp_charging_sessions

```sql
CREATE TABLE ocpp_charging_sessions (
  id BIGINT PRIMARY KEY,
  charge_point_id BIGINT NOT NULL REFERENCES ocpp_charge_points(id),
  connector_id INTEGER NOT NULL,
  transaction_id VARCHAR UNIQUE,
  id_tag VARCHAR,
  status VARCHAR DEFAULT 'Preparing',
  started_at TIMESTAMP,
  stopped_at TIMESTAMP,
  start_meter_value DECIMAL(10,2),
  stop_meter_value DECIMAL(10,2),
  energy_consumed DECIMAL(10,2),
  duration_seconds INTEGER,
  stop_reason VARCHAR,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_cs_charge_point ON ocpp_charging_sessions(charge_point_id);
CREATE INDEX idx_cs_composite ON ocpp_charging_sessions(charge_point_id, connector_id);
CREATE UNIQUE INDEX idx_cs_transaction ON ocpp_charging_sessions(transaction_id);
```

### ocpp_meter_values

```sql
CREATE TABLE ocpp_meter_values (
  id BIGINT PRIMARY KEY,
  charging_session_id BIGINT REFERENCES ocpp_charging_sessions(id),
  charge_point_id BIGINT NOT NULL REFERENCES ocpp_charge_points(id),
  connector_id INTEGER,
  measurand VARCHAR,
  phase VARCHAR,
  unit VARCHAR,
  context VARCHAR,
  format VARCHAR,
  location VARCHAR,
  value DECIMAL(15,4),
  timestamp TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_mv_session ON ocpp_meter_values(charging_session_id);
CREATE INDEX idx_mv_charge_point ON ocpp_meter_values(charge_point_id);
CREATE INDEX idx_mv_measurand ON ocpp_meter_values(measurand);
CREATE INDEX idx_mv_timestamp ON ocpp_meter_values(timestamp);
```

### ocpp_messages

```sql
CREATE TABLE ocpp_messages (
  id BIGINT PRIMARY KEY,
  charge_point_id BIGINT NOT NULL REFERENCES ocpp_charge_points(id),
  message_id VARCHAR NOT NULL,
  direction VARCHAR NOT NULL,
  action VARCHAR,
  message_type VARCHAR NOT NULL,
  payload JSONB DEFAULT '{}',
  status VARCHAR,
  error_message TEXT,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_msg_charge_point ON ocpp_messages(charge_point_id);
CREATE INDEX idx_msg_message_id ON ocpp_messages(message_id);
CREATE INDEX idx_msg_composite ON ocpp_messages(charge_point_id, created_at);
```

---

## Helper Methods

### Testing Helpers

See [Testing Guide](testing.md) for `OcppTestHelper` documentation.

---

**Next**: [Message Reference](message-reference.md) →  
**Back**: [Configuration Guide](configuration.md) ←