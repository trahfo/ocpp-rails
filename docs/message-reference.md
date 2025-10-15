# OCPP Message Reference

Complete reference for OCPP 1.6 message formats used in OCPP Rails.

**Navigation**: [← Back to Documentation Index](README.md) | [Remote Charging Guide →](remote-charging.md)

## Table of Contents

- [Message Format](#message-format)
- [Charge Point to Central System](#charge-point-to-central-system)
  - [Authorize](#authorize)
  - [BootNotification](#bootnotification)
  - [Heartbeat](#heartbeat)
  - [MeterValues](#metervalues)
  - [StartTransaction](#starttransaction)
  - [StopTransaction](#stoptransaction)
- [Central System to Charge Point](#central-system-to-charge-point)
  - [RemoteStartTransaction](#remotestarttransaction)
  - [RemoteStopTransaction](#remotestoptransaction)
- [Common Data Types](#common-data-types)

## Message Format

OCPP 1.6 uses JSON-RPC 2.0 over WebSocket. All messages follow one of three formats:

### CALL (Request)

```json
[2, "message-id", "Action", {"key": "value"}]
```

- `2` - Message type (CALL)
- `message-id` - Unique message identifier (UUID)
- `Action` - OCPP action name
- `{}` - Payload object

### CALLRESULT (Response)

```json
[3, "message-id", {"key": "value"}]
```

- `3` - Message type (CALLRESULT)
- `message-id` - Same as request
- `{}` - Response payload

### CALLERROR (Error)

```json
[4, "message-id", "ErrorCode", "ErrorDescription", {"key": "value"}]
```

- `4` - Message type (CALLERROR)
- `message-id` - Same as request
- `ErrorCode` - Error code string
- `ErrorDescription` - Human-readable error
- `{}` - Error details object

## Charge Point to Central System

### Authorize

Request authorization for an ID tag.

#### Authorize.req

```json
[2, "19223201", "Authorize", {
  "idTag": "RFID_USER_001"
}]
```

**Fields:**
- `idTag` (String, required) - ID tag to authorize (max 20 chars)

#### Authorize.conf

```json
[3, "19223201", {
  "idTagInfo": {
    "status": "Accepted",
    "expiryDate": "2025-12-31T23:59:59Z",
    "parentIdTag": "PARENT_001"
  }
}]
```

**Fields:**
- `idTagInfo.status` (String, required) - Authorization status
  - `Accepted` - ID tag accepted
  - `Blocked` - ID tag blocked
  - `Expired` - ID tag expired
  - `Invalid` - ID tag invalid
  - `ConcurrentTx` - Already in use
- `idTagInfo.expiryDate` (String, optional) - ISO 8601 datetime
- `idTagInfo.parentIdTag` (String, optional) - Parent ID tag

---

### BootNotification

Register charge point with central system.

#### BootNotification.req

```json
[2, "19223201", "BootNotification", {
  "chargePointVendor": "ABB",
  "chargePointModel": "Terra 54",
  "chargePointSerialNumber": "SN123456789",
  "chargeBoxSerialNumber": "CB123456",
  "firmwareVersion": "1.0.0",
  "iccid": "89014104277001122334",
  "imsi": "310410123456789",
  "meterType": "EnergyMeter",
  "meterSerialNumber": "MTR123456"
}]
```

**Required Fields:**
- `chargePointVendor` (String, max 20) - Manufacturer name
- `chargePointModel` (String, max 20) - Model name

**Optional Fields:**
- `chargePointSerialNumber` (String, max 25)
- `chargeBoxSerialNumber` (String, max 25)
- `firmwareVersion` (String, max 50)
- `iccid` (String, max 20) - SIM card ICCID
- `imsi` (String, max 20) - SIM card IMSI
- `meterType` (String, max 25)
- `meterSerialNumber` (String, max 25)

#### BootNotification.conf

```json
[3, "19223201", {
  "status": "Accepted",
  "currentTime": "2024-01-15T10:30:00Z",
  "interval": 300
}]
```

**Fields:**
- `status` (String, required) - Registration status
  - `Accepted` - Charge point accepted
  - `Pending` - Awaiting approval
  - `Rejected` - Rejected
- `currentTime` (String, required) - ISO 8601 datetime
- `interval` (Integer, required) - Heartbeat interval in seconds

---

### Heartbeat

Periodic keep-alive message.

#### Heartbeat.req

```json
[2, "19223201", "Heartbeat", {}]
```

**Fields:** None (empty payload)

#### Heartbeat.conf

```json
[3, "19223201", {
  "currentTime": "2024-01-15T10:30:00Z"
}]
```

**Fields:**
- `currentTime` (String, required) - ISO 8601 datetime

---

### MeterValues

Periodic meter readings during charging.

#### MeterValues.req

```json
[2, "19223201", "MeterValues", {
  "connectorId": 1,
  "transactionId": 12345,
  "meterValue": [{
    "timestamp": "2024-01-15T10:35:00Z",
    "sampledValue": [
      {
        "value": "12345",
        "context": "Sample.Periodic",
        "format": "Raw",
        "measurand": "Energy.Active.Import.Register",
        "phase": "L1",
        "location": "Outlet",
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

**Fields:**
- `connectorId` (Integer, required) - Connector number
- `transactionId` (Integer, optional) - Transaction ID if in transaction
- `meterValue` (Array, required) - Array of meter value objects
  - `timestamp` (String, required) - ISO 8601 datetime
  - `sampledValue` (Array, required) - Array of sampled values
    - `value` (String, required) - Measured value as string
    - `context` (String, optional) - Reading context
      - `Sample.Periodic` - Periodic sample
      - `Sample.Clock` - Clock-aligned sample
      - `Transaction.Begin` - Transaction start
      - `Transaction.End` - Transaction end
    - `measurand` (String, optional) - Type of measurement (default: Energy.Active.Import.Register)
    - `phase` (String, optional) - Phase (L1, L2, L3, N, L1-N, L2-N, L3-N, L1-L2, L2-L3, L3-L1)
    - `location` (String, optional) - Location (Inlet, Outlet, Body)
    - `unit` (String, optional) - Unit of measure (Wh, kWh, varh, kvarh, W, kW, VA, kVA, var, kvar, A, V, K, Celsius, Fahrenheit, Percent)
    - `format` (String, optional) - Value format (Raw, SignedData)

**Common Measurands:**
- `Energy.Active.Import.Register` - Total imported energy (Wh)
- `Power.Active.Import` - Instantaneous power (W)
- `Current.Import` - Current (A)
- `Voltage` - Voltage (V)
- `SoC` - State of Charge (%)
- `Temperature` - Temperature (°C)

#### MeterValues.conf

```json
[3, "19223201", {}]
```

**Fields:** None (empty payload)

---

### StartTransaction

Start a charging transaction.

#### StartTransaction.req

```json
[2, "19223201", "StartTransaction", {
  "connectorId": 1,
  "idTag": "RFID_USER_001",
  "meterStart": 1000,
  "reservationId": 12345,
  "timestamp": "2024-01-15T10:30:00Z"
}]
```

**Required Fields:**
- `connectorId` (Integer) - Connector number
- `idTag` (String, max 20) - Authorization ID
- `meterStart` (Integer) - Meter value at start (Wh)
- `timestamp` (String) - ISO 8601 datetime

**Optional Fields:**
- `reservationId` (Integer) - Reservation ID if using reservation

#### StartTransaction.conf

```json
[3, "19223201", {
  "transactionId": 12345,
  "idTagInfo": {
    "status": "Accepted",
    "expiryDate": "2025-12-31T23:59:59Z",
    "parentIdTag": "PARENT_001"
  }
}]
```

**Fields:**
- `transactionId` (Integer, required) - Assigned transaction ID
- `idTagInfo` (Object, required) - Authorization info
  - `status` (String, required) - See Authorize status values
  - `expiryDate` (String, optional) - ISO 8601 datetime
  - `parentIdTag` (String, optional) - Parent ID tag

---

### StopTransaction

Stop a charging transaction.

#### StopTransaction.req

```json
[2, "19223201", "StopTransaction", {
  "idTag": "RFID_USER_001",
  "meterStop": 15000,
  "timestamp": "2024-01-15T11:00:00Z",
  "transactionId": 12345,
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

**Required Fields:**
- `meterStop` (Integer) - Meter value at stop (Wh)
- `timestamp` (String) - ISO 8601 datetime
- `transactionId` (Integer) - Transaction ID from StartTransaction

**Optional Fields:**
- `idTag` (String, max 20) - ID tag used to stop
- `reason` (String) - Stop reason
  - `Local` - Stopped at charge point
  - `Remote` - Stopped remotely
  - `EmergencyStop` - Emergency stop
  - `EVDisconnected` - EV disconnected
  - `HardReset` - Hard reset
  - `PowerLoss` - Power loss
  - `Reboot` - Reboot
  - `SoftReset` - Soft reset
  - `UnlockCommand` - Unlock command
  - `DeAuthorized` - Deauthorized
  - `Other` - Other reason
- `transactionData` (Array) - Meter values during transaction

#### StopTransaction.conf

```json
[3, "19223201", {
  "idTagInfo": {
    "status": "Accepted",
    "expiryDate": "2025-12-31T23:59:59Z",
    "parentIdTag": "PARENT_001"
  }
}]
```

**Fields:**
- `idTagInfo` (Object, optional) - Authorization info

---

## Central System to Charge Point

### RemoteStartTransaction

Remotely start a charging transaction.

#### RemoteStartTransaction.req

```json
[2, "19223201", "RemoteStartTransaction", {
  "connectorId": 1,
  "idTag": "RFID_USER_001",
  "chargingProfile": {
    "chargingProfileId": 1,
    "stackLevel": 0,
    "chargingProfilePurpose": "TxProfile",
    "chargingProfileKind": "Absolute",
    "chargingSchedule": {
      "chargingRateUnit": "W",
      "chargingSchedulePeriod": [
        {
          "startPeriod": 0,
          "limit": 7200
        }
      ]
    }
  }
}]
```

**Required Fields:**
- `idTag` (String, max 20) - Authorization ID

**Optional Fields:**
- `connectorId` (Integer) - Specific connector (if not provided, CP chooses)
- `chargingProfile` (Object) - Charging profile to apply
  - `chargingProfileId` (Integer) - Profile ID
  - `stackLevel` (Integer) - Stack level (0-highest priority)
  - `chargingProfilePurpose` (String) - Purpose (TxProfile, TxDefaultProfile, ChargePointMaxProfile)
  - `chargingProfileKind` (String) - Kind (Absolute, Recurring, Relative)
  - `chargingSchedule` (Object) - Schedule
    - `chargingRateUnit` (String) - Unit (W or A)
    - `chargingSchedulePeriod` (Array) - Schedule periods
      - `startPeriod` (Integer) - Start offset in seconds
      - `limit` (Decimal) - Power/current limit

#### RemoteStartTransaction.conf

```json
[3, "19223201", {
  "status": "Accepted"
}]
```

**Fields:**
- `status` (String, required) - Response status
  - `Accepted` - Command accepted
  - `Rejected` - Command rejected

---

### RemoteStopTransaction

Remotely stop a charging transaction.

#### RemoteStopTransaction.req

```json
[2, "19223201", "RemoteStopTransaction", {
  "transactionId": 12345
}]
```

**Required Fields:**
- `transactionId` (Integer) - Transaction ID to stop

#### RemoteStopTransaction.conf

```json
[3, "19223201", {
  "status": "Accepted"
}]
```

**Fields:**
- `status` (String, required) - Response status
  - `Accepted` - Command accepted
  - `Rejected` - Command rejected (transaction not found)

---

## Common Data Types

### IdTagInfo

Authorization information for an ID tag.

```json
{
  "status": "Accepted",
  "expiryDate": "2025-12-31T23:59:59Z",
  "parentIdTag": "PARENT_001"
}
```

**Fields:**
- `status` (String, required) - Authorization status
- `expiryDate` (String, optional) - ISO 8601 datetime
- `parentIdTag` (String, optional) - Parent ID tag (max 20 chars)

### MeterValue

Meter reading with timestamp and sampled values.

```json
{
  "timestamp": "2024-01-15T10:35:00Z",
  "sampledValue": [
    {
      "value": "12345",
      "context": "Sample.Periodic",
      "measurand": "Energy.Active.Import.Register",
      "unit": "Wh"
    }
  ]
}
```

### ChargingProfile

Power/current limits and schedules.

```json
{
  "chargingProfileId": 1,
  "stackLevel": 0,
  "chargingProfilePurpose": "TxProfile",
  "chargingProfileKind": "Absolute",
  "chargingSchedule": {
    "chargingRateUnit": "W",
    "chargingSchedulePeriod": [
      {
        "startPeriod": 0,
        "limit": 7200
      }
    ]
  }
}
```

---

## Error Codes

Common OCPP error codes used in CALLERROR messages:

- `NotImplemented` - Operation not supported
- `NotSupported` - Request not supported
- `InternalError` - Internal error
- `ProtocolError` - Protocol error
- `SecurityError` - Security error
- `FormationViolation` - Message formation violation
- `PropertyConstraintViolation` - Property constraint violation
- `OccurrenceConstraintViolation` - Occurrence constraint violation
- `TypeConstraintViolation` - Type constraint violation
- `GenericError` - Generic error

### Example Error Response

```json
[4, "19223201", "NotImplemented", "Operation not supported", {}]
```

---

## Usage in OCPP Rails

### Accessing Messages

```ruby
# Get recent messages
messages = charge_point.messages.recent.limit(10)

# Filter by action
start_messages = charge_point.messages.where(action: "StartTransaction")

# View message payload
message = charge_point.messages.last
puts JSON.pretty_generate(message.payload)

# Filter by direction
inbound = charge_point.messages.inbound  # CP → CS
outbound = charge_point.messages.outbound  # CS → CP
```

### Creating Messages

Messages are typically created automatically by jobs and handlers, but you can create them manually:

```ruby
charge_point.messages.create!(
  message_id: SecureRandom.uuid,
  direction: "outbound",
  action: "RemoteStartTransaction",
  message_type: "CALL",
  payload: {
    connectorId: 1,
    idTag: "RFID_USER_001"
  },
  status: "pending"
)
```

---

## Additional Resources

- [OCPP 1.6 Edition 2 Specification](../ocpp-1.6_edition_2.md) - Complete specification
- [Remote Charging Guide](remote-charging.md) - Implementation examples
- [API Reference](api-reference.md) - Model and controller documentation
- [Testing Guide](testing.md) - Message testing examples

---

**Next**: [Testing Guide](testing.md) →  
**Back**: [API Reference](api-reference.md) ←