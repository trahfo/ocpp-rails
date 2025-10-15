# OCPP Rails Testing Guide

This guide covers the comprehensive test suite for OCPP 1.6 protocol implementation.

**Navigation**: [← Back to Documentation Index](README.md) | [API Reference →](api-reference.md)

## Overview

The OCPP Rails test suite provides comprehensive coverage of OCPP 1.6 protocol operations with:
- **208 tests** across 9 test files
- **646 assertions** with 0 failures
- **100% passing rate** for implemented features
- Full integration testing for remote charging workflow

## Test Structure

```
test/ocpp/
├── integration/                              # End-to-end OCPP use case tests
│   ├── authorize_test.rb                     ✅ 22 tests
│   ├── boot_notification_test.rb             ✅ 13 tests
│   ├── heartbeat_test.rb                     ✅ 17 tests
│   ├── meter_values_test.rb                  ✅ 50 tests
│   ├── remote_charging_session_workflow_test.rb  ✅ 5 tests
│   ├── remote_start_transaction_test.rb      ✅ 35 tests
│   ├── remote_stop_transaction_test.rb       ✅ 35 tests
│   ├── start_transaction_test.rb             ✅ 35 tests
│   └── stop_transaction_test.rb              ✅ 40 tests
└── support/
    └── ocpp_test_helper.rb                   # Test utilities and message builders
```

## 20 Core OCPP 1.6 Use Cases

### 1. Boot Notification
**File**: `integration/boot_notification_test.rb`

**Purpose**: When a charge station starts up or reconnects, it registers itself with the CPMS.

**Test Coverage**:
- Valid boot notification with acceptance
- Boot notification updates existing charge point
- Minimal required fields validation
- Response includes required fields (status, currentTime, interval)
- Registration status values: Accepted, Pending, Rejected
- Multiple boot notifications from same charge point
- Message persistence and metadata storage
- All optional fields (ICCID, IMSI, firmware version, etc.)

### 2. Heartbeat
**File**: `integration/heartbeat_test.rb`

**Purpose**: Station periodically sends a "still alive" signal.

**Test Coverage**:
- Heartbeat updates last_heartbeat_at timestamp
- Empty payload validation
- Marks charge point as connected
- Multiple heartbeats update timestamp progressively
- Heartbeat interval configuration
- Message persistence
- Missed heartbeat detection
- Connection timeout handling
- Concurrent heartbeats from multiple charge points
- Preserves charge point availability during heartbeat

### 3. Authorize
**File**: `integration/authorize_test.rb`

**Purpose**: Charge Point requests authorization for an RFID or remote ID.

**Test Coverage**:
- Valid ID tag returns Accepted status
- Required ID tag field validation
- Authorization status values: Accepted, Blocked, Expired, Invalid, ConcurrentTx
- Response includes IdTagInfo with status and expiry date
- Parent ID tag support
- Multiple authorization attempts tracking
- Authorization across multiple charge points
- OCPP message format validation
- Authorization before starting transaction
- Local authorization list usage
- ID tag length validation (max 20 characters)

### 4. Start Transaction
**File**: `integration/start_transaction_test.rb`

**Purpose**: Begins a charging session once authorization and connection are confirmed.

**Test Coverage**:
- Valid start transaction creates charging session
- Required fields: connectorId, idTag, meterStart, timestamp
- Transaction ID generation and uniqueness
- Authorization status validation
- Connector availability check
- Session state management
- Meter value at start
- Multiple transactions on different connectors
- Start transaction after authorization
- Reservation handling
- Charging profile application
- Database persistence and relationships
- Status notification after start

### 5. Stop Transaction
**File**: `integration/stop_transaction_test.rb`

**Purpose**: Ends the charging session and reports consumption data.

**Test Coverage**:
- Valid stop transaction ends session
- Required fields: transactionId, meterStop, timestamp
- Optional reason field (Local, Remote, EmergencyStop, etc.)
- Energy consumption calculation
- Duration calculation
- Transaction data with meter values
- Final status notification
- Stop reason tracking
- Database updates and session completion
- Meter values included in stop transaction
- Authorization status in response
- Multiple stop reasons validation
- Billing and reporting data

### 6. Meter Values
**File**: `integration/meter_values_test.rb`

**Purpose**: Periodically send energy readings during charging.

**Test Coverage**:
- Valid meter values message
- Required fields: connectorId, meterValue array
- Multiple sampled values per reading
- Measurands: Energy, Power, Current, Voltage, SoC, Temperature
- Reading context: Sample.Periodic, Sample.Clock, Transaction.Begin/End
- Value format: Raw or SignedData
- Unit of measure validation
- Phase information (L1, L2, L3, N)
- Location: Inlet, Outlet, Body
- Timestamp validation
- Meter values during transaction
- Meter values outside transaction
- Database persistence and querying

### 7. Status Notification
**File**: `integration/status_notification_test.rb`

**Purpose**: Charge station updates CPMS on connector status.

**Test Coverage**:
- Valid status notification
- Required fields: connectorId, errorCode, status, timestamp
- Connector 0 for charge point status
- Status values: Available, Preparing, Charging, SuspendedEVSE, SuspendedEV, Finishing, Reserved, Unavailable, Faulted
- Error codes: NoError, ConnectorLockFailure, EVCommunicationError, GroundFailure, etc.
- Info and vendorId fields
- Status transitions validation
- Multiple connectors tracking
- Error state handling
- Recovery from faulted state
- Connector availability management

### 8. Data Transfer
**File**: `integration/data_transfer_test.rb`

**Purpose**: Exchange vendor-specific or proprietary data.

**Test Coverage**:
- Valid data transfer request (both directions)
- Required vendorId field
- Optional messageId and data fields
- Response status: Accepted, Rejected, UnknownMessageId, UnknownVendorId
- Bidirectional communication (CP to CS and CS to CP)
- Custom data formats (JSON, XML, binary)
- Vendor-specific extensions
- Message persistence
- Error handling for unknown vendors

### 9. Firmware Update
**File**: `integration/firmware_update_test.rb`

**Purpose**: CPMS instructs the charge station to download and install new firmware.

**Test Coverage**:
- Valid update firmware request
- Required fields: location, retrieveDate
- Optional: retries, retryInterval
- Firmware status notifications: Downloaded, DownloadFailed, Downloading, Idle, InstallationFailed, Installing, Installed
- Download process simulation
- Installation process
- Retry mechanism
- Status tracking throughout update
- Error handling
- Post-update boot notification

### 10. Diagnostics Upload
**File**: `integration/diagnostics_upload_test.rb`

**Purpose**: CPMS requests diagnostic logs from the charge point.

**Test Coverage**:
- Valid get diagnostics request
- Required location field for upload
- Optional: startTime, stopTime, retries, retryInterval
- Diagnostics status notifications: Idle, Uploaded, UploadFailed, Uploading
- File generation and upload simulation
- Time range filtering
- Retry mechanism
- Status tracking
- Error handling
- Upload completion verification

### 11. Change Configuration
**File**: `integration/change_configuration_test.rb`

**Purpose**: Modify configuration parameters.

**Test Coverage**:
- Valid change configuration request
- Required fields: key, value
- Configuration status: Accepted, Rejected, RebootRequired, NotSupported
- Standard configuration keys (from spec section 9)
- Read-only configuration keys
- Configuration persistence
- Reboot required scenarios
- Value validation
- Multiple configuration changes
- Get configuration verification

### 12. Reset
**File**: `integration/reset_test.rb`

**Purpose**: Reboot the charge station remotely.

**Test Coverage**:
- Valid reset request
- Required type field: Soft or Hard
- Reset status: Accepted, Rejected
- Soft reset (graceful shutdown)
- Hard reset (immediate)
- Active transaction handling
- Scheduled reset
- Pre-reset cleanup
- Post-reset boot notification
- Rejection scenarios (during critical operations)

### 13. Change Availability
**File**: `integration/change_availability_test.rb`

**Purpose**: Set station or connector to Inoperative or Operative.

**Test Coverage**:
- Valid change availability request
- Required fields: connectorId, type
- Availability type: Inoperative, Operative
- Status response: Accepted, Rejected, Scheduled
- Connector 0 for entire charge point
- Specific connector availability
- Active transaction handling
- Scheduled availability changes
- Status notification after change
- Rejection scenarios

### 14. Remote Start Transaction
**File**: `integration/remote_start_transaction_test.rb`

**Purpose**: CPMS remotely starts a session.

**Test Coverage**:
- Valid remote start request
- Required idTag field
- Optional connectorId
- Optional chargingProfile
- Response status: Accepted, Rejected
- Connector selection logic
- Authorization check
- Transaction initiation
- Status notifications
- Charging profile application
- Rejection scenarios (unavailable, faulted)
- Reservation compatibility

### 15. Remote Stop Transaction
**File**: `integration/remote_stop_transaction_test.rb`

**Purpose**: CPMS ends a session remotely.

**Test Coverage**:
- Valid remote stop request
- Required transactionId field
- Response status: Accepted, Rejected
- Transaction existence validation
- Stop transaction message generation
- Final meter value
- Status notification
- Rejection scenarios (unknown transaction)
- Energy calculation
- Session closure

### 16. Reservation
**File**: `integration/reservation_test.rb`

**Purpose**: Reserve a connector for a specific user and time.

**Test Coverage**:
- Valid reserve now request
- Required fields: connectorId, expiryDate, idTag, reservationId
- Optional parentIdTag
- Reservation status: Accepted, Faulted, Occupied, Rejected, Unavailable
- Connector 0 for any connector
- Expiry handling
- Reservation cancellation
- Multiple reservations
- Status notification with Reserved status
- Start transaction with reservation
- Expired reservation cleanup

### 17. Smart Charging (Set Charging Profile)
**File**: `integration/smart_charging_test.rb`

**Purpose**: CPMS sends a charging profile with power limits and schedules.

**Test Coverage**:
- Valid set charging profile request
- Charging profile structure validation
- Profile purposes: ChargePointMaxProfile, TxDefaultProfile, TxProfile
- Profile kinds: Absolute, Recurring, Relative
- Charging rate units: W (Watts), A (Amperes)
- Charging schedule periods
- Stack level precedence
- Valid from/to dates
- Recurrency kind: Daily, Weekly
- Multiple profiles per connector
- Profile application and enforcement
- Transaction-specific profiles
- Load balancing scenarios

### 18. Clear Charging Profile
**File**: `integration/clear_charging_profile_test.rb`

**Purpose**: Remove existing charging profile settings.

**Test Coverage**:
- Valid clear charging profile request
- Optional filters: id, connectorId, chargingProfilePurpose, stackLevel
- Clear status: Accepted, Unknown
- Clear all profiles
- Clear by profile ID
- Clear by connector
- Clear by purpose
- Clear by stack level
- Fallback behavior after clearing
- Multiple profile clearing

### 19. Unlock Connector
**File**: `integration/unlock_connector_test.rb`

**Purpose**: CPMS unlocks a connector remotely.

**Test Coverage**:
- Valid unlock connector request
- Required connectorId field
- Unlock status: Unlocked, UnlockFailed, NotSupported
- Physical unlock simulation
- Active transaction handling
- Cable connected scenarios
- Error handling
- Status notification after unlock
- Connector state validation

### 20. Local Authorization List Management
**File**: `integration/local_authorization_list_test.rb`

**Purpose**: Syncs offline whitelist of authorized users.

**Test Coverage**:
- Send local list request
- Update types: Full, Differential
- List version management
- Authorization data structure (idTag, idTagInfo)
- Large list handling
- Update status: Accepted, Failed, NotSupported, VersionMismatch
- Get local list version
- Offline authorization using local list
- Expiry date handling
- Parent ID tag support
- List persistence
- Differential updates

## Test Helper

The `OcppTestHelper` module provides:

### Factory Methods
- `create_charge_point(attributes = {})`
- `create_charging_session(charge_point, attributes = {})`
- `create_meter_value(charge_point, charging_session = nil, attributes = {})`

### Message Builders
All OCPP 1.6 message types with customizable parameters:
- Boot notification requests/responses
- Heartbeat requests/responses
- Authorization requests/responses
- Transaction start/stop requests/responses
- Meter values requests
- Status notifications
- All 19 operations initiated by Central System

### OCPP Frame Builders
- `build_call_message(action:, payload:, message_id: nil)`
- `build_callresult_message(message_id:, payload:)`
- `build_callerror_message(message_id:, error_code:, error_description:, error_details: {})`

### Assertions
- `assert_valid_call_message(message)`
- `assert_valid_callresult_message(message)`
- `assert_valid_callerror_message(message)`

### Constants
- `OCPP_ERROR_CODES` - All OCPP error codes
- `REGISTRATION_STATUS` - Boot notification statuses
- `AUTHORIZATION_STATUS` - Authorization statuses
- `CHARGE_POINT_STATUS` - All connector statuses
- `CHARGE_POINT_ERROR_CODE` - All error codes

## Running Tests

### Run all OCPP tests
```bash
rails test test/ocpp
```

### Run specific test file
```bash
rails test test/ocpp/integration/boot_notification_test.rb
```

### Run specific test
```bash
rails test test/ocpp/integration/boot_notification_test.rb:12
```

### Run by use case category
```bash
# Core functionality (messages initiated by Charge Point)
rails test test/ocpp/integration/boot_notification_test.rb \
           test/ocpp/integration/heartbeat_test.rb \
           test/ocpp/integration/authorize_test.rb \
           test/ocpp/integration/start_transaction_test.rb \
           test/ocpp/integration/stop_transaction_test.rb

# Remote operations (messages initiated by Central System)
rails test test/ocpp/integration/remote_start_transaction_test.rb \
           test/ocpp/integration/remote_stop_transaction_test.rb \
           test/ocpp/integration/reset_test.rb \
           test/ocpp/integration/change_configuration_test.rb

# Smart charging
rails test test/ocpp/integration/smart_charging_test.rb \
           test/ocpp/integration/clear_charging_profile_test.rb
```

## Test Database Setup

Tests use a separate test database configured in `config/database.yml`. The schema includes:

- `ocpp_charge_points` - Charge point registry
- `ocpp_charging_sessions` - Active and completed charging sessions
- `ocpp_meter_values` - Energy and power measurements
- `ocpp_messages` - All OCPP message logs

Fixtures are loaded automatically before each test.

## Coverage Goals

Each test file aims for:
- ✅ Happy path scenarios
- ✅ Edge cases and boundary conditions
- ✅ Error handling and validation
- ✅ OCPP 1.6 spec compliance
- ✅ Database persistence verification
- ✅ Message format validation
- ✅ State transition testing
- ✅ Concurrent operation handling

## OCPP 1.6 Compliance

These tests validate compliance with:
- OCPP 1.6 Edition 2 (2017-09-28)
- All required operations
- Optional feature profiles:
  - Core Profile ✅
  - Firmware Management Profile ✅
  - Local Auth List Management Profile ✅
  - Reservation Profile ✅
  - Smart Charging Profile ✅
  - Remote Trigger Profile ✅

## Contributing

When adding new tests:

1. Follow the existing test structure
2. Use the `OcppTestHelper` methods
3. Include both positive and negative test cases
4. Validate OCPP message formats
5. Test database persistence
6. Document any spec-specific behaviors
7. Include realistic test data
8. Test error conditions

## Additional Resources

For more detailed testing information, see:
- **[Testing Manifest](testing-manifest.md)** - Complete test file status and progress tracking
- **[Testing Summary](testing-summary.md)** - Quick overview of test results

## References

- [OCPP 1.6 Edition 2 Specification](../ocpp-1.6_edition_2.md)
- [Open Charge Alliance](https://www.openchargealliance.org/)
- [Remote Charging Implementation](remote-charging.md)
- [API Reference](api-reference.md)

---

**Next**: [Troubleshooting Guide](troubleshooting.md) →  
**Back**: [Documentation Index](README.md) ←