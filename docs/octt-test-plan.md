# OCTT OCPP 1.6 Compliance — Central System Test Plan

Source: Open Charge Alliance *"Test case document OCTT for OCPP 1.6"* (2025-02),
Section 3 — System Under Test (SUT) = Central System. `ocpp-rails` plays the
Central System role, so Section 3 is the relevant OCTT chapter; Section 2
(SUT = Charge Point) is out of scope.

This document is the **detailed, per-case specification** for every OCTT Central
System test case — both the ones already implemented and the ones still missing.
Each case has a Given/When/Then (Gherkin) spec so a contributor can turn it into a
test without re-reading the OCTT PDF.

> **This file is the source of truth for per-case status.** The headline numbers in the
> [README → OCPP 1.6 Compliance Status](../README.md#-ocpp-16-compliance-status) mirror the
> [Coverage at a glance](#coverage-at-a-glance) table below.

## How coverage is judged

A case only counts as tested if a **real, handler/job-driven** test exercises it —
i.e. a test that pushes a frame through `MessageHandler`, an `Actions::*Handler`, or
an outbound job and asserts on the actual behavior. The bulk of the files under
`test/ocpp/integration/*` are *simulation-style*: they build request/response
hashes and create model rows by hand without invoking any production code, so they
do **not** prove wire-protocol compliance and are not counted as coverage here.

## Legend

| Status | Meaning | Contributor action |
|---|---|---|
| ✅ Implemented + tested | Engine implements it **and** a real handler/job test guards it | None (extend if the case has noted sub-gaps) |
| 🟡 Implemented — needs test | Behavior works, but no real OCTT-style regression test yet | Write the test below |
| 🔴 Not implemented | Message/operation does not exist in the engine | Build the code **and** the test below |
| ⚪ Out of scope | Handled by infrastructure (TLS termination), not app code | Cover in your deployment's infra tests |

---

## Coverage at a glance

_Last updated: 2026-07-07. Measured against OCTT (2025-02) Section 3 (SUT = Central System) — **76** cases._

| | Cases | Meaning |
|---|---:|---|
| ✅ Implemented + tested | 32 | Works **and** guarded by a real handler/job-driven test |
| 🟡 Implemented — needs test | 0 | Behavior works, only simulation-style coverage |
| 🔴 Not implemented | 42 | Message/operation not in the engine yet |
| ⚪ Out of scope | 2 | TLS handshake (TC_086/087) — infra, not app code |

**32 of 76 cases (42%) are backed by working code — and every one now has a real regression test** (the 🟡 bucket is empty). The remaining 42 span Local Auth List, Firmware, Diagnostics, Reservation, Remote Trigger, Smart Charging, DataTransfer and Security profiles 2/3.

> The index below covers the **74 cases specified in this document**; the other 2 of the 76 OCTT Section-3 cases are not yet written up here and count as 🔴 Not implemented.

### Full case index

| Case | Feature | Status | Test file / gap |
|---|---|---|---|
| **[1. Boot / Charging Sessions / Cache](#1-boot-charging-sessions-cache)** | | | |
| TC_001 | Cold Boot Charge Point | ✅ | `boot_notification_handler_test.rb` |
| TC_003 | Regular Charging Session – Plugin First | ✅ | `status_notification_handler_test.rb`, `start_transaction_authorization_test.rb` |
| TC_004_1 | Regular Charging Session – Identification First | ✅ | authorize + status + start handler tests |
| TC_004_2 | Identification First – ConnectionTimeOut | ✅ | `status_notification_handler_test.rb` |
| TC_005_1 | EV Side Disconnected | ✅ | `stop_transaction_reason_test.rb` |
| TC_007 | Regular Start – Cached Id | ✅ | `start_transaction_authorization_test.rb` |
| TC_061 | Clear Authorization Data in Cache | ✅ | `clear_cache_job_test.rb` |
| **[2. Remote Start / Stop](#2-remote-start--stop)** | | | |
| TC_010 | Remote Start – Cable Plugged in First | ✅ | `integration/remote_start_flow_test.rb` |
| TC_011_1 | Remote Start – Remote Start First | ✅ | `integration/remote_start_flow_test.rb` |
| TC_011_2 | Remote Start – Time Out | ✅ | `integration/remote_start_flow_test.rb` |
| TC_012 | Remote Stop Charging Session | ✅ | `integration/remote_stop_flow_test.rb` |
| TC_026 | Remote Start – Rejected | ✅ | `outbound_delivery_test.rb` |
| TC_028 | Remote Stop – Rejected | ✅ | `outbound_delivery_test.rb` |
| **[3. Reset / Unlock / Configuration](#3-reset--unlock--configuration-core-profile)** | | | |
| TC_013 | Hard Reset | ✅ | `reset_job_test.rb` |
| TC_014 | Soft Reset | ✅ | `reset_job_test.rb` |
| TC_017_1 | Unlock Connector – no session | ✅ | `unlock_connector_job_test.rb` |
| TC_017_2 | Unlock Connector – no session (NotSupported) | ✅ | `unlock_connector_job_test.rb` |
| TC_018_1 | Unlock Connector – with active session | ✅ | `unlock_connector_job_test.rb` |
| TC_019_1 | Retrieve all configuration keys | ✅ | `get_configuration_job_test.rb` |
| TC_019_2 | Retrieve specific configuration key | ✅ | `get_configuration_job_test.rb` |
| TC_021 | Change/set Configuration | ✅ | `change_configuration_job_test.rb` |
| TC_040_1 | Configuration key – NotSupported | ✅ | `change_configuration_job_test.rb` |
| TC_040_2 | Configuration Keys – Invalid value | ✅ | `change_configuration_job_test.rb` |
| **[4. Authorize non-happy paths](#4-authorize-non-happy-paths)** | | | |
| TC_023_1 | Authorize invalid | ✅ | `authorize_handler_test.rb` |
| TC_023_2 | Authorize expired | ✅ | `authorize_handler_test.rb` |
| TC_023_3 | Authorize blocked | ✅ | `authorize_handler_test.rb` |
| TC_024 | Start Charging Session Lock Failure | ✅ | `status_notification_handler_test.rb` |
| **[5. Offline / power-loss](#5-offline--power-loss-behavior)** | | | |
| TC_032_1 | Power failure boot, stop transaction(s) | ✅ | `integration/power_failure_recovery_test.rb` |
| TC_037_1 | Offline Start – Valid IdTag | ✅ | `integration/offline_transaction_test.rb` |
| TC_037_3 | Offline Start – Invalid IdTag | ✅ | `integration/offline_transaction_test.rb` |
| TC_039 | Offline Transaction | ✅ | `integration/offline_transaction_test.rb` |
| **[6. Local Authorization List](#6-local-authorization-list)** | | | |
| TC_042_1 | Get Local List Version (not supported) | 🔴 | no GetLocalListVersion |
| TC_042_2 | Get Local List Version (empty) | 🔴 | no GetLocalListVersion |
| TC_043_1 | Send Local Authorization List – NotSupported | 🔴 | no SendLocalList |
| TC_043_3 | Send Local Authorization List – Failed | 🔴 | no SendLocalList |
| TC_043_4 | Send Local Authorization List – Full | 🔴 | no SendLocalList |
| TC_043_5 | Send Local Authorization List – Differential | 🔴 | no SendLocalList |
| **[7. Firmware Management](#7-firmware-management)** | | | |
| TC_044_1 | Firmware Update – Download and Install | 🔴 | no UpdateFirmware |
| TC_044_2 | Firmware Update – Download Failed | 🔴 | no UpdateFirmware |
| TC_044_3 | Firmware Update – Installation Failed | 🔴 | no UpdateFirmware |
| **[8. Diagnostics](#8-diagnostics)** | | | |
| TC_045_1 | Get Diagnostics | 🔴 | no GetDiagnostics |
| TC_045_2 | Get Diagnostics – Upload Failed | 🔴 | no GetDiagnostics |
| **[9. Reservation](#9-reservation)** | | | |
| TC_046 | Reservation of a Connector – Transaction | 🔴 | no ReserveNow |
| TC_047 | Reservation of a Connector – Expire | 🔴 | no ReserveNow |
| TC_048_1 | Reservation – Faulted | 🔴 | no ReserveNow |
| TC_048_2 | Reservation – Occupied | 🔴 | no ReserveNow |
| TC_048_3 | Reservation – Unavailable | 🔴 | no ReserveNow / ChangeAvailability |
| TC_048_4 | Reservation – Rejected | 🔴 | no ReserveNow |
| TC_049 | Reservation of a Charge Point (connectorId 0) | 🔴 | no ReserveNow |
| TC_051 | Cancel Reservation | 🔴 | no CancelReservation |
| TC_052 | Cancel Reservation – Rejected | 🔴 | no CancelReservation |
| TC_053 | Use a reserved Connector with parentIdTag | 🔴 | no ReserveNow |
| **[10. RemoteTrigger](#10-remotetrigger)** | | | |
| TC_054 | Trigger Message | 🔴 | no TriggerMessage |
| TC_055 | Trigger Message – Rejected | 🔴 | no TriggerMessage |
| **[11. Smart Charging](#11-smart-charging)** | | | |
| TC_056 | Central Smart Charging – TxDefaultProfile | 🔴 | no SetChargingProfile |
| TC_057 | Central Smart Charging – TxProfile | 🔴 | no SetChargingProfile |
| TC_066 | Get Composite Schedule | 🔴 | no GetCompositeSchedule |
| TC_067 | Clear Charging Profile | 🔴 | no ClearChargingProfile |
| TC_059 | Remote Start Transaction with Charging Profile | 🔴 | job lacks chargingProfile arg |
| **[12. DataTransfer](#12-datatransfer)** | | | |
| TC_064 | Data Transfer to a Central System | 🔴 | no inbound DataTransfer handler |
| **[13. Security (profiles 1–3)](#13-security-profiles-13)** | | | |
| TC_073 | Update Charge Point Password (Basic Auth) | 🔴 | needs ChangeConfiguration |
| TC_074 | Update Charge Point Certificate | 🔴 | no certificate management |
| TC_075_1 | Install certificate (Manufacturer root) | 🔴 | no InstallCertificate |
| TC_075_2 | Install certificate (CentralSystem root) | 🔴 | no InstallCertificate |
| TC_076 | Delete a specific certificate | 🔴 | no DeleteCertificate |
| TC_077 | Invalid ChargePointCertificate Security Event | 🔴 | no SecurityEventNotification |
| TC_078 | Invalid CentralSystemCertificate Security Event | 🔴 | no SecurityEventNotification |
| TC_079 | Get Security Log | 🔴 | no GetLog |
| TC_080 | Secure Firmware Update | 🔴 | no SignedUpdateFirmware |
| TC_081 | Secure Firmware Update – Invalid Signature | 🔴 | no SignedUpdateFirmware |
| TC_083 | Upgrade Charge Point Security Profile | 🔴 | needs ChangeConfiguration + Reset |
| TC_085 | Basic Authentication – Valid combination | ✅ | `station_authentication_test.rb` |
| TC_086 | TLS server-side certificate | ⚪ | infra (reverse proxy) |
| TC_087 | TLS client-side certificate | ⚪ | infra (reverse proxy) |

> **Reading the detail sections below:** their per-case **Existing coverage** / **Suggested file** notes were written *before* the July 2026 test round. The **Status** line (updated) and the index above are authoritative — for any ✅ case, its **Suggested file** is the test that now exists.

---

## 1. Boot, Charging Sessions, Cache

### TC_001_CSMS — Cold Boot Charge Point
**Ref:** 3.1.1 · **Status:** ✅ Implemented + tested
**Existing coverage:** `BootNotificationHandler`, `HeartbeatHandler`, `StatusNotificationHandler` all exist and work; only simulation-style assertions exist today (`test/ocpp/integration/boot_notification_test.rb`), which do not drive the handlers.
**Suggested file:** `test/ocpp/boot_notification_handler_test.rb`

```gherkin
Feature: Cold boot registration
  Scenario: Charge point boots and the Central System accepts it
    Given no charge point is registered with identifier "CP_BOOT_1"
    When the charge point sends a BootNotification.req for that identifier
    Then the Central System responds with BootNotification.conf status "Accepted"
    And the response interval equals the configured heartbeat_interval
    And the response includes a currentTime

  Scenario: Charge point reports per-connector status after boot
    Given a booted charge point
    When it sends StatusNotification.req for connectorId 0 and each connector with status "Available"
    Then the Central System responds with StatusNotification.conf for each message

  Scenario: Charge point sends periodic heartbeats after boot
    Given a booted charge point
    When it sends a Heartbeat.req
    Then the Central System responds with Heartbeat.conf including currentTime
```

### TC_003_CSMS — Regular Charging Session - Plugin First
**Ref:** 3.2.1 · **Status:** ✅ Implemented + tested
**Existing coverage:** the accepted StartTransaction path is asserted by `test/ocpp/start_transaction_authorization_test.rb`; the StatusNotification (Preparing/Charging) and Authorize.req legs are not driven by any real test.
**Suggested file:** `test/ocpp/status_notification_handler_test.rb` + extend `start_transaction_authorization_test.rb`

```gherkin
Feature: Cable plugged in before authorization
  Scenario: Preparing status is acknowledged
    Given a booted, idle charge point
    When it sends StatusNotification.req with status "Preparing" for the connector
    Then the Central System responds with StatusNotification.conf

  Scenario: Authorize is accepted before StartTransaction
    Given a booted, idle charge point
    When it sends Authorize.req with a valid idTag
    Then Authorize.conf idTagInfo.status is "Accepted"

  Scenario: Transaction starts and the connector goes to Charging
    Given the driver has been authorized
    When the charge point sends StartTransaction.req for the connector and idTag
    Then StartTransaction.conf idTagInfo.status is "Accepted"
    And a subsequent StatusNotification.req with status "Charging" is acknowledged
```

### TC_004_1_CSMS — Regular Charging Session – Identification First
**Ref:** 3.2.2 · **Status:** ✅ Implemented + tested
**Existing coverage:** same handlers as TC_003; no real end-to-end test of the identification-first ordering.
**Suggested file:** `test/ocpp/status_notification_handler_test.rb`

```gherkin
Feature: Identification before cable plug-in
  Scenario: Reusable state "Authorized" then a normal start
    Given Authorize.req with a valid idTag has already been accepted
    When the charge point sends StatusNotification.req status "Preparing"
    And then sends StartTransaction.req with the same idTag
    Then StartTransaction.conf idTagInfo.status is "Accepted"
    And StatusNotification.req status "Charging" is acknowledged afterwards
```

### TC_004_2_CSMS — Identification First - ConnectionTimeOut
**Ref:** 3.2.3 · **Status:** ✅ Implemented + tested
**Existing coverage:** `StatusNotificationHandler` acknowledges any status; no timer logic is required of the CS. No real test asserts the Available acknowledgement.
**Suggested file:** `test/ocpp/status_notification_handler_test.rb`

```gherkin
Feature: Connector reverts to Available after connection timeout
  Scenario: Charge point reports the connector as Available again
    Given the driver has been authorized but never plugs in
    When the charge point sends StatusNotification.req status "Available" after its configured ConnectionTimeOut
    Then the Central System responds with StatusNotification.conf
```

### TC_005_1_CSMS — EV Side Disconnected (StopTransactionOnEVSideDisconnect=true, UnlockConnectorOnEVSideDisconnect=true)
**Ref:** 3.2.4 · **Status:** ✅ Implemented + tested
**Existing coverage:** `StopTransactionHandler` accepts any stop reason and the session→connector state transitions work; `test/ocpp/wire_transaction_id_test.rb` covers stop resolution generically. The EVDisconnected-specific status sequence is not asserted.
**Suggested file:** `test/ocpp/stop_transaction_reason_test.rb`

```gherkin
Feature: EV-side disconnect stops the transaction
  Background:
    Given an active charging session on connector 1

  Scenario: SuspendedEV is acknowledged
    When the charge point sends StatusNotification.req status "SuspendedEV"
    Then the Central System responds with StatusNotification.conf

  Scenario: StopTransaction with reason EVDisconnected is accepted
    When the charge point sends StopTransaction.req with reason "EVDisconnected" for the session's transactionId
    Then StopTransaction.conf idTagInfo.status is "Accepted"

  Scenario: Connector returns to Available
    Given the transaction has been stopped
    When the charge point sends StatusNotification.req status "Finishing" then "Available"
    Then each is acknowledged with StatusNotification.conf
```

### TC_007_CSMS — Regular Start Charging Session – Cached Id
**Ref:** 3.3.1 · **Status:** ✅ Implemented + tested
**Existing coverage:** `test/ocpp/start_transaction_authorization_test.rb` asserts an accepted idTag starts a session; it does not explicitly assert the "no Authorize.req was sent first" (cached-id) semantics.
**Suggested file:** `test/ocpp/start_transaction_authorization_test.rb`

```gherkin
Feature: StartTransaction with a cached authorization, no Authorize.req sent
  Scenario: StartTransaction is accepted without a preceding Authorize call
    Given a valid idTag that the authorization hook accepts
    And no Authorize.req has been sent for this idTag
    When the charge point sends StartTransaction.req directly
    Then StartTransaction.conf idTagInfo.status is "Accepted"
    And a ChargingSession is created for the connector
```

### TC_061_CSMS — Clear Authorization Data in Authorization Cache
**Ref:** 3.3.2 · **Status:** ✅ Implemented + tested
**Implemented:** `ClearCacheJob` (`app/jobs/ocpp/rails/clear_cache_job.rb`), covered by `test/ocpp/clear_cache_job_test.rb`.
**Suggested file:** `test/ocpp/clear_cache_job_test.rb`

```gherkin
Feature: Central System clears the charge point's authorization cache
  Scenario: ClearCache.req is delivered to the station
    Given a connected charge point
    When the Central System enqueues a ClearCache operation for it
    Then a CALL frame with action "ClearCache" is broadcast on the station's stream
    And the outbound Message is recorded with status "pending"

  Scenario: Accepted confirmation is recorded
    Given a pending outbound ClearCache Message
    When the charge point responds with ClearCache.conf status "Accepted"
    Then the Message status becomes "received" and its response payload contains status "Accepted"
```

---

## 2. Remote Start / Stop

### TC_010_CSMS — Remote Start – Cable Plugged in First
**Ref:** 3.4.1 · **Status:** ✅ Implemented + tested
**Existing coverage:** `test/ocpp/outbound_delivery_test.rb` asserts `RemoteStartTransactionJob` delivers the correct CALL frame on the station's stream and records a pending Message. The subsequent Authorize→StartTransaction chain triggered by the remote start is not yet asserted end-to-end.
**Suggested file:** `test/ocpp/integration/remote_start_flow_test.rb` (real handlers, not the existing simulation-style file of the same name)

```gherkin
Feature: Remote start transaction end-to-end
  Scenario: Cable plugged in first, then remote start
    Given a booted charge point with StatusNotification "Preparing" already reported
    When RemoteStartTransactionJob is performed for that connector and a valid idTag
    Then a RemoteStartTransaction CALL is broadcast on the station's stream
    And when the charge point subsequently sends Authorize.req for that idTag, it is Accepted
    And when it sends StartTransaction.req, StartTransaction.conf idTagInfo.status is "Accepted"
```

### TC_011_1_CSMS — Remote Start – Remote Start First
**Ref:** 3.4.2 · **Status:** ✅ Implemented + tested
**Existing coverage:** delivery covered by `test/ocpp/outbound_delivery_test.rb`; remote-first ordering not asserted end-to-end.
**Suggested file:** `test/ocpp/integration/remote_start_flow_test.rb`

```gherkin
Feature: Remote start issued before plug-in
  Scenario: Remote start issued before plug-in
    Given a booted, idle charge point
    When RemoteStartTransactionJob is performed before any StatusNotification is sent
    And the charge point later sends StatusNotification "Preparing" then StartTransaction.req
    Then StartTransaction.conf idTagInfo.status is "Accepted"
```

### TC_011_2_CSMS — Remote Start – Time Out
**Ref:** 3.4.3 · **Status:** ✅ Implemented + tested
**Existing coverage:** delivery covered by `test/ocpp/outbound_delivery_test.rb`; the timeout is a charge-point-side behavior, the CS only needs to acknowledge the resulting StatusNotifications (untested).
**Suggested file:** `test/ocpp/integration/remote_start_flow_test.rb`

```gherkin
Feature: Remote start times out because the cable is never plugged in
  Scenario: Connector returns to Available without a StartTransaction
    Given RemoteStartTransactionJob has been performed
    When the charge point sends StatusNotification "Preparing" then, after its ConnectionTimeOut, "Available"
    Then no StartTransaction.req is ever sent
    And both StatusNotification messages are acknowledged
```

### TC_012_CSMS — Remote Stop Charging Session
**Ref:** 3.4.4 · **Status:** ✅ Implemented + tested
**Existing coverage:** `test/ocpp/outbound_delivery_test.rb` asserts `RemoteStopTransactionJob` delivers the correct CALL; the resulting StopTransaction(reason=Remote)→Finishing→Available sequence is not asserted end-to-end.
**Suggested file:** `test/ocpp/integration/remote_stop_flow_test.rb`

```gherkin
Feature: Remote stop transaction end-to-end
  Background:
    Given an active charging session

  Scenario: Remote stop leads to a StopTransaction with reason Remote
    When RemoteStopTransactionJob is performed for the session's transactionId
    Then a RemoteStopTransaction CALL is broadcast on the station's stream
    And when the charge point sends StopTransaction.req with reason "Remote", it is accepted
    And a following StatusNotification "Finishing" then "Available" is acknowledged
```

### TC_026_CSMS — Remote Start – Rejected
**Ref:** 3.9.1 · **Status:** ✅ Implemented + tested
**Existing coverage:** `MessageHandler#handle_callresult` stores any inbound `.conf` against the pending Message; no test asserts the Rejected case specifically.
**Suggested file:** `test/ocpp/outbound_delivery_test.rb` (extend)

```gherkin
Feature: Central System handles a rejected remote start
  Scenario: RemoteStartTransaction.conf status Rejected is recorded without error
    Given a pending outbound RemoteStartTransaction Message
    When the charge point responds with RemoteStartTransaction.conf status "Rejected"
    Then the Message status becomes "received"
    And no StartTransaction is expected or required afterward
```

### TC_028_CSMS — Remote Stop – Rejected
**Ref:** 3.9.2 · **Status:** ✅ Implemented + tested
**Existing coverage:** generic `.conf` handling as above; no dedicated test.
**Suggested file:** `test/ocpp/outbound_delivery_test.rb` (extend)

```gherkin
Feature: Central System handles a rejected remote stop
  Scenario: RemoteStopTransaction.conf status Rejected is recorded without error
    Given an active session and a pending outbound RemoteStopTransaction Message referencing an unknown transactionId
    When the charge point responds with RemoteStopTransaction.conf status "Rejected"
    Then the Message status becomes "received"
    And the original session remains active and untouched
```

---

## 3. Reset / Unlock / Configuration (Core profile)

### TC_013_CSMS — Hard Reset
**Ref:** 3.5.1 · **Status:** ✅ Implemented + tested
**Implemented:** `ResetJob` (`app/jobs/ocpp/rails/reset_job.rb`), covered by `test/ocpp/reset_job_test.rb`.
**Suggested file:** `test/ocpp/reset_job_test.rb`

```gherkin
Feature: Central System triggers a hard reset
  Scenario: Reset.req is delivered with type Hard
    Given a connected charge point
    When the Central System enqueues a Reset operation with type "Hard"
    Then a CALL frame with action "Reset" and payload type "Hard" is broadcast on the station's stream

  Scenario: Charge point re-registers after rebooting
    Given the charge point accepted the Reset.req
    When it sends a new BootNotification.req
    Then BootNotification.conf status is "Accepted"
    And subsequent StatusNotification.req messages for each connector are acknowledged
```

### TC_014_CSMS — Soft Reset
**Ref:** 3.5.2 · **Status:** ✅ Implemented + tested
**Suggested file:** `test/ocpp/reset_job_test.rb`

```gherkin
Feature: Central System triggers a soft reset
  Scenario: Reset.req is delivered with type Soft
    Given a connected charge point
    When the Central System enqueues a Reset operation with type "Soft"
    Then a CALL frame with action "Reset" and payload type "Soft" is broadcast on the station's stream
```

### TC_017_1_CSMS / TC_017_2_CSMS — Unlock Connector (no session)
**Ref:** 3.6.1–3.6.2 · **Status:** ✅ Implemented + tested
**Implemented:** `UnlockConnectorJob` (`app/jobs/ocpp/rails/unlock_connector_job.rb`), covered by `test/ocpp/unlock_connector_job_test.rb`.
**Suggested file:** `test/ocpp/unlock_connector_job_test.rb`

```gherkin
Feature: Central System unlocks a connector with no active session
  Scenario: UnlockConnector.req is delivered
    Given a connected charge point with no active session
    When the Central System enqueues an UnlockConnector operation for a connector
    Then a CALL frame with action "UnlockConnector" and the connectorId is broadcast

  Scenario: Charge point confirms the connector is unlocked
    Given a pending outbound UnlockConnector Message
    When the charge point responds with UnlockConnector.conf status "Unlocked"
    Then the Message status becomes "received"

  Scenario: Charge point reports a fixed cable cannot be unlocked
    Given a pending outbound UnlockConnector Message
    When the charge point responds with UnlockConnector.conf status "NotSupported"
    Then the Message status becomes "received" without raising an error
```

### TC_018_1_CSMS — Unlock Connector - With Charging Session
**Ref:** 3.6.3 · **Status:** ✅ Implemented + tested
**Suggested file:** `test/ocpp/unlock_connector_job_test.rb`

```gherkin
Feature: Unlocking a connector during an active transaction stops it
  Background:
    Given an active charging session on connector 1

  Scenario: Unlock succeeds and the transaction is stopped
    When the Central System enqueues an UnlockConnector operation for connector 1
    And the charge point responds with UnlockConnector.conf status "Unlocked"
    Then when the charge point sends StatusNotification "Finishing" it is acknowledged
    And when it sends StopTransaction.req with reason "UnlockCommand" it is accepted
    And a following StatusNotification "Available" is acknowledged
```

### TC_019_1_CSMS — Retrieve all configuration keys
**Ref:** 3.7.1 · **Status:** ✅ Implemented + tested
**Implemented:** `GetConfigurationJob` (`app/jobs/ocpp/rails/get_configuration_job.rb`), covered by `test/ocpp/get_configuration_job_test.rb`.
**Suggested file:** `test/ocpp/get_configuration_job_test.rb`

```gherkin
Feature: Central System retrieves all configuration keys
  Scenario: GetConfiguration.req is sent with an empty key list
    Given a connected charge point
    When the Central System enqueues a GetConfiguration operation with no keys specified
    Then a CALL frame with action "GetConfiguration" and an omitted or empty key list is broadcast

  Scenario: The configuration response is stored
    Given a pending outbound GetConfiguration Message
    When the charge point responds with GetConfiguration.conf listing its configurationKey entries
    Then the Message status becomes "received" with the key/value pairs in its response payload
```

### TC_019_2_CSMS — Retrieve specific configuration key
**Ref:** 3.7.2 · **Status:** ✅ Implemented + tested
**Suggested file:** `test/ocpp/get_configuration_job_test.rb`

```gherkin
Feature: Central System retrieves one configuration key
  Scenario: GetConfiguration.req is sent with a single key
    Given a connected charge point
    When the Central System enqueues a GetConfiguration operation for key "SupportedFeatureProfiles"
    Then a CALL frame with action "GetConfiguration" and key ["SupportedFeatureProfiles"] is broadcast

  Scenario: An unknownKey-free response is accepted
    Given a pending outbound GetConfiguration Message for "SupportedFeatureProfiles"
    When the charge point responds with an empty unknownKey list and a matching configurationKey entry
    Then the Message status becomes "received"
```

### TC_021_CSMS — Change/set Configuration
**Ref:** 3.7.3 · **Status:** ✅ Implemented + tested
**Implemented:** `ChangeConfigurationJob` (`app/jobs/ocpp/rails/change_configuration_job.rb`), covered by `test/ocpp/change_configuration_job_test.rb`.
**Suggested file:** `test/ocpp/change_configuration_job_test.rb`

```gherkin
Feature: Central System changes a configuration value
  Scenario: ChangeConfiguration.req is sent with a key and value
    Given a connected charge point
    When the Central System enqueues a ChangeConfiguration operation for key "MeterValueSampleInterval" value "60"
    Then a CALL frame with action "ChangeConfiguration" and that key/value is broadcast

  Scenario: Accepted confirmation is recorded
    Given a pending outbound ChangeConfiguration Message
    When the charge point responds with ChangeConfiguration.conf status "Accepted"
    Then the Message status becomes "received"
```

### TC_040_1_CSMS — Configuration key - NotSupported
**Ref:** 3.13.1 · **Status:** ✅ Implemented + tested
**Suggested file:** `test/ocpp/change_configuration_job_test.rb`

```gherkin
Feature: Central System handles an unsupported configuration key
  Scenario: NotSupported confirmation does not raise
    Given a pending outbound ChangeConfiguration Message for an unknown key
    When the charge point responds with ChangeConfiguration.conf status "NotSupported"
    Then the Message status becomes "received" without error
```

### TC_040_2_CSMS — Configuration Keys - Invalid value
**Ref:** 3.13.2 · **Status:** ✅ Implemented + tested
**Suggested file:** `test/ocpp/change_configuration_job_test.rb`

```gherkin
Feature: Central System handles a rejected configuration value
  Scenario: Rejected confirmation does not raise
    Given a pending outbound ChangeConfiguration Message for key "MeterValueSampleInterval"
    When the charge point responds with ChangeConfiguration.conf status "Rejected"
    Then the Message status becomes "received" without error
```

---

## 4. Authorize non-happy paths

### TC_023_1_CSMS — Authorize invalid
**Ref:** 3.8.1 · **Status:** ✅ Implemented + tested
**Existing coverage:** `AuthorizeHandler` returns the hook's status, and rejection-blocks-a-transaction is asserted for the StartTransaction path in `test/ocpp/start_transaction_authorization_test.rb`. The Authorize.req path itself has no dedicated test.
**Suggested file:** `test/ocpp/authorize_handler_test.rb`

```gherkin
Feature: Authorize rejects an invalid idTag
  Scenario: Invalid idTag receives an Invalid status
    Given an authorization hook that reports an unknown idTag as invalid
    When the charge point sends Authorize.req with that idTag
    Then Authorize.conf idTagInfo.status is "Invalid"
```

### TC_023_2_CSMS — Authorize expired
**Ref:** 3.8.2 · **Status:** ✅ Implemented + tested
**Existing coverage:** expired-blocks-a-transaction is asserted for StartTransaction in `test/ocpp/start_transaction_authorization_test.rb`; the Authorize.req path is not.
**Suggested file:** `test/ocpp/authorize_handler_test.rb`

```gherkin
Feature: Authorize rejects an expired idTag
  Scenario: Expired idTag receives an Expired status
    Given an authorization hook that reports this idTag as expired
    When the charge point sends Authorize.req with that idTag
    Then Authorize.conf idTagInfo.status is "Expired"
```

### TC_023_3_CSMS — Authorize blocked
**Ref:** 3.8.3 · **Status:** ✅ Implemented + tested
**Existing coverage:** blocked-blocks-a-transaction is asserted for StartTransaction in `test/ocpp/start_transaction_authorization_test.rb`; the Authorize.req path is not.
**Suggested file:** `test/ocpp/authorize_handler_test.rb`

```gherkin
Feature: Authorize rejects a blocked idTag
  Scenario: Blocked idTag receives a Blocked status
    Given an authorization hook that reports this idTag as blocked
    When the charge point sends Authorize.req with that idTag
    Then Authorize.conf idTagInfo.status is "Blocked"
```

### TC_024_CSMS — Start Charging Session Lock Failure
**Ref:** 3.8.4 · **Status:** ✅ Implemented + tested
**Existing coverage:** `StatusNotificationHandler` stores `errorCode` in connector metadata and logs a StateChange; no real test asserts the ConnectorLockFailure/Faulted case.
**Suggested file:** `test/ocpp/status_notification_handler_test.rb`

```gherkin
Feature: Connector lock failure is reported and acknowledged
  Background:
    Given the driver has been authorized

  Scenario: Preparing is acknowledged
    When the charge point sends StatusNotification.req status "Preparing"
    Then the Central System responds with StatusNotification.conf

  Scenario: A lock failure fault is stored and acknowledged
    When the charge point sends StatusNotification.req with errorCode "ConnectorLockFailure" and status "Faulted"
    Then the Central System responds with StatusNotification.conf
    And the connector's stored error_code is "ConnectorLockFailure"
```

---

## 5. Offline / power-loss behavior

### TC_032_1_CSMS — Power failure boot, configured to stop transaction(s)
**Ref:** 3.11.1 · **Status:** ✅ Implemented + tested
**Existing coverage:** boot re-registration and stop-with-reason are individually implemented; no test drives the mid-transaction reboot → Finishing/Available → StopTransaction(PowerLoss) sequence.
**Suggested file:** `test/ocpp/integration/power_failure_recovery_test.rb`

```gherkin
Feature: Charge point recovers from a power failure mid-transaction
  Background:
    Given an active charging session on connector 1

  Scenario: Reboot after power loss re-registers normally
    When the charge point sends a new BootNotification.req
    Then BootNotification.conf status is "Accepted"

  Scenario: The connector that had the transaction reports Finishing, others report Available
    Given the charge point has rebooted
    When it sends StatusNotification.req status "Finishing" for connector 1 and "Available" for the others
    Then each is acknowledged with StatusNotification.conf

  Scenario: The interrupted transaction is stopped with reason PowerLoss
    When the charge point sends StopTransaction.req with reason "PowerLoss" for the session's transactionId
    Then StopTransaction.conf idTagInfo.status is "Accepted"
```

### TC_037_1_CSMS — Offline Start Transaction - Valid IdTag
**Ref:** 3.12.1 · **Status:** ✅ Implemented + tested
**Existing coverage:** `StartTransactionHandler` accepts past-dated timestamps (timestamp provenance is covered by `test/ocpp/timestamp_provenance_test.rb`); the offline-queue-replay case isn't asserted specifically.
**Suggested file:** `test/ocpp/integration/offline_transaction_test.rb`

```gherkin
Feature: Charge point submits a transaction started while offline
  Scenario: A queued StartTransaction with a valid idTag is accepted late
    Given a valid idTag
    When the charge point sends StartTransaction.req after reconnecting, timestamped in the past
    Then StartTransaction.conf idTagInfo.status is "Accepted"
    And a following StatusNotification.req status "Charging" is acknowledged
```

### TC_037_3_CSMS — Offline Start Transaction - Invalid IdTag, StopTransactionOnInvalidId=true
**Ref:** 3.12.2 · **Status:** ✅ Implemented + tested
**Existing coverage:** invalid-idTag rejection is covered by `test/ocpp/start_transaction_authorization_test.rb`; the offline unwind sequence (Charging→DeAuthorized→Finishing) isn't.
**Suggested file:** `test/ocpp/integration/offline_transaction_test.rb`

```gherkin
Feature: Charge point submits an offline transaction with an idTag that turns out invalid
  Scenario: StartTransaction is rejected but the charge point still unwinds the session
    Given an idTag the authorization hook reports as invalid
    When the charge point sends StartTransaction.req for it after reconnecting
    Then StartTransaction.conf idTagInfo.status is "Invalid"
    And when the charge point sends StatusNotification.req status "Charging" it is acknowledged
    And when it sends StopTransaction.req with reason "DeAuthorized" it does not error
    And a following StatusNotification.req status "Finishing" is acknowledged
```

### TC_039_CSMS — Offline Transaction
**Ref:** 3.12.3 · **Status:** ✅ Implemented + tested
**Existing coverage:** start and stop handlers work; no test drives a fully-offline start+stop pair replayed on reconnect.
**Suggested file:** `test/ocpp/integration/offline_transaction_test.rb`

```gherkin
Feature: A full transaction that started and stopped while offline is submitted on reconnect
  Scenario: Queued StartTransaction and StopTransaction are both accepted
    Given a valid idTag
    When the charge point sends StartTransaction.req after reconnecting
    Then StartTransaction.conf idTagInfo.status is "Accepted"
    When it then sends StopTransaction.req with reason "Local" for that transactionId
    Then StopTransaction.conf idTagInfo.status is "Accepted"
```

---

## 6. Local Authorization List

### TC_042_1_CSMS — Get Local List Version (not supported)
**Ref:** 3.14.1 · **Status:** 🔴 Not implemented
**Gap:** No outbound `GetLocalListVersion` operation, and the Local Auth List Management feature profile isn't implemented at all.
**Suggested file:** `test/ocpp/local_auth_list_job_test.rb`

```gherkin
Feature: Central System queries the local list version
  Scenario: Charge point reports the feature as unsupported
    Given a connected charge point
    When the Central System enqueues a GetLocalListVersion operation
    Then a CALL frame with action "GetLocalListVersion" is broadcast
    And when the charge point responds with listVersion -1, the Message is recorded as received without error
```

### TC_042_2_CSMS — Get Local List Version (empty)
**Ref:** 3.14.1 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/local_auth_list_job_test.rb`

```gherkin
Feature: Central System queries an empty local list
  Scenario: Charge point reports version 0
    Given a connected charge point
    When the Central System enqueues a GetLocalListVersion operation
    Then when the charge point responds with listVersion 0, the Message is recorded as received
```

### TC_043_1_CSMS — Send Local Authorization List - NotSupported
**Ref:** 3.14.2 · **Status:** 🔴 Not implemented
**Gap:** No outbound `SendLocalList` operation.
**Suggested file:** `test/ocpp/local_auth_list_job_test.rb`

```gherkin
Feature: Central System sends a full local authorization list
  Scenario: SendLocalList.req is delivered with updateType Full
    Given a connected charge point and at least one idToken to authorize
    When the Central System enqueues a SendLocalList operation with updateType "Full"
    Then a CALL frame with action "SendLocalList" and updateType "Full" is broadcast

  Scenario: NotSupported confirmation does not raise
    Given a pending outbound SendLocalList Message
    When the charge point responds with SendLocalList.conf status "NotSupported"
    Then the Message status becomes "received" without error
```

### TC_043_3_CSMS — Send Local Authorization List - Failed
**Ref:** 3.14.2 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/local_auth_list_job_test.rb`

```gherkin
Feature: Central System handles a failed local list update
  Scenario: Failed confirmation does not raise
    Given a pending outbound SendLocalList Message with updateType "Full"
    When the charge point responds with SendLocalList.conf status "Failed"
    Then the Message status becomes "received" without error
```

### TC_043_4_CSMS — Send Local Authorization List - Full
**Ref:** 3.14.2 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/local_auth_list_job_test.rb`

```gherkin
Feature: Central System sends a full local authorization list successfully
  Scenario: Every entry carries idTagInfo and the update is accepted
    Given a connected charge point and a list of idTokens each with an idTagInfo
    When the Central System enqueues a SendLocalList operation with updateType "Full" and that list
    Then the broadcast payload's localAuthorizationList entries each include an idTagInfo
    And when the charge point responds with SendLocalList.conf status "Accepted", the Message is recorded as received
```

### TC_043_5_CSMS — Send Local Authorization List - Differential
**Ref:** 3.14.2 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/local_auth_list_job_test.rb`

```gherkin
Feature: Central System sends a differential local authorization list update
  Scenario: Differential update adds a single idToken with an incremented version
    Given a local list already sent with an initial listVersion
    When the Central System enqueues a SendLocalList operation with updateType "Differential", a single new idToken, and a versionNumber greater than the initial one
    Then the broadcast payload's localAuthorizationList contains only that idToken with an idTagInfo
    And when the charge point responds with SendLocalList.conf status "Accepted", the Message is recorded as received
```

---

## 7. Firmware Management

### TC_044_1_CSMS — Firmware Update - Download and Install
**Ref:** 3.15.1 · **Status:** 🔴 Not implemented
**Gap:** No outbound `UpdateFirmware` operation and no inbound `FirmwareStatusNotification` handler.
**Suggested file:** `test/ocpp/firmware_update_test.rb`

```gherkin
Feature: Central System triggers and tracks a firmware update
  Scenario: UpdateFirmware.req is sent with the download location
    Given a connected charge point
    When the Central System enqueues an UpdateFirmware operation with a firmware location
    Then a CALL frame with action "UpdateFirmware" and that firmware.location is broadcast

  Scenario: The full status progression is acknowledged
    Given a pending outbound UpdateFirmware Message
    When the charge point sends FirmwareStatusNotification.req with status "Downloading"
    Then the Central System responds with FirmwareStatusNotification.conf
    When it then sends status "Downloaded", "Installing", and finally "Installed"
    Then each is acknowledged with FirmwareStatusNotification.conf

  Scenario: The charge point reconnects and reports Available after installing
    Given the firmware has been installed
    When the charge point sends a new BootNotification.req followed by StatusNotification "Available"
    Then both are acknowledged
```

### TC_044_2_CSMS — Firmware Update - Download Failed
**Ref:** 3.15.2 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/firmware_update_test.rb`

```gherkin
Feature: Central System handles a failed firmware download
  Scenario: DownloadFailed status is acknowledged
    Given a pending outbound UpdateFirmware Message
    When the charge point sends FirmwareStatusNotification.req with status "Downloading" then "DownloadFailed"
    Then each is acknowledged with FirmwareStatusNotification.conf
```

### TC_044_3_CSMS — Firmware Update - Installation Failed
**Ref:** 3.15.3 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/firmware_update_test.rb`

```gherkin
Feature: Central System handles a failed firmware installation
  Scenario: InstallationFailed status is acknowledged after a reboot attempt
    Given a pending outbound UpdateFirmware Message
    When the charge point progresses through Downloading, Downloaded, and Installing
    And then reboots and sends a new BootNotification.req
    And then sends FirmwareStatusNotification.req status "InstallationFailed"
    Then the Central System acknowledges every message without error
```

---

## 8. Diagnostics

### TC_045_1_CSMS — Get Diagnostics
**Ref:** 3.16.1 · **Status:** 🔴 Not implemented
**Gap:** No outbound `GetDiagnostics` operation and no inbound `DiagnosticsStatusNotification` handler.
**Suggested file:** `test/ocpp/get_diagnostics_test.rb`

```gherkin
Feature: Central System retrieves a diagnostics file
  Scenario: GetDiagnostics.req is sent with an upload location
    Given a connected charge point
    When the Central System enqueues a GetDiagnostics operation with an upload location
    Then a CALL frame with action "GetDiagnostics" is broadcast

  Scenario: Upload progress is acknowledged
    Given a pending outbound GetDiagnostics Message
    When the charge point sends DiagnosticsStatusNotification.req status "Uploading" then "Uploaded"
    Then each is acknowledged with DiagnosticsStatusNotification.conf
```

### TC_045_2_CSMS — Get Diagnostics - Upload Failed
**Ref:** 3.16.2 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/get_diagnostics_test.rb`

```gherkin
Feature: Central System handles a failed diagnostics upload
  Scenario: UploadFailed status is acknowledged
    Given a pending outbound GetDiagnostics Message
    When the charge point sends DiagnosticsStatusNotification.req status "Uploading" then "UploadFailed"
    Then each is acknowledged with DiagnosticsStatusNotification.conf
```

---

## 9. Reservation

### TC_046_CSMS — Reservation of a Connector - Transaction
**Ref:** 3.17.1 · **Status:** 🔴 Not implemented
**Gap:** No outbound `ReserveNow`/`CancelReservation` operations; the Reservation feature profile isn't implemented (no Reservation model).
**Suggested file:** `test/ocpp/reservation_test.rb`

```gherkin
Feature: Central System reserves a connector and the reservation is honored
  Scenario: ReserveNow.req is sent for a specific connector and idTag
    Given a connected charge point
    When the Central System enqueues a ReserveNow operation for a connector, a valid idTag, and a reservationId
    Then a CALL frame with action "ReserveNow" carrying that connectorId and idTag is broadcast

  Scenario: The connector reports Reserved
    Given a pending outbound ReserveNow Message
    When the charge point responds with ReserveNow.conf status "Accepted"
    And then sends StatusNotification.req status "Reserved"
    Then both are acknowledged

  Scenario: Charging with the reserved idTag references the reservation
    Given the connector is reserved with a given reservationId
    When the driver authorizes and starts a transaction on it
    Then the resulting StartTransaction.req's reservationId matches the one from the ReserveNow.req
```

### TC_047_CSMS — Reservation of a Connector - Expire
**Ref:** 3.17.1 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/reservation_test.rb`

```gherkin
Feature: An unused reservation expires
  Scenario: Reservation carries an expiryDate and the connector reverts to Available
    Given a connected charge point
    When the Central System enqueues a ReserveNow operation with an expiryDate offset from now
    Then the broadcast ReserveNow.req carries that expiryDate
    And when the charge point later sends StatusNotification.req status "Available" after the expiry, it is acknowledged
```

### TC_048_1_CSMS — Reservation - Faulted
**Ref:** 3.17.1 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/reservation_test.rb`

```gherkin
Feature: Central System handles a reservation that could not be made
  Scenario: Faulted confirmation does not raise
    Given a pending outbound ReserveNow Message
    When the charge point responds with ReserveNow.conf status "Faulted"
    Then the Message status becomes "received" without error
```

### TC_048_2_CSMS — Reservation - Occupied
**Ref:** 3.17.1 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/reservation_test.rb`

```gherkin
Feature: Central System handles a reservation attempt on an occupied connector
  Scenario: Occupied confirmation does not raise
    Given the connector already reported StatusNotification "Preparing"
    When the Central System enqueues a ReserveNow operation for that connector
    And the charge point responds with ReserveNow.conf status "Occupied"
    Then the Message status becomes "received" without error
```

### TC_048_3_CSMS — Reservation - Unavailable
**Ref:** 3.17.1 · **Status:** 🔴 Not implemented
**Note:** also exercises outbound `ChangeAvailability` (type Inoperative) — now implemented (`ChangeAvailabilityJob`, tested in `test/ocpp/change_availability_job_test.rb`); the ReserveNow half is still 🔴.
**Suggested file:** `test/ocpp/reservation_test.rb`

```gherkin
Feature: Central System handles a reservation attempt on an unavailable connector
  Scenario: Unavailable confirmation does not raise
    Given the Central System has set the connector Inoperative via ChangeAvailability
    And the charge point reported StatusNotification "Unavailable" for it
    When the Central System enqueues a ReserveNow operation for that connector
    And the charge point responds with ReserveNow.conf status "Unavailable"
    Then the Message status becomes "received" without error
```

### TC_048_4_CSMS — Reservation - Rejected
**Ref:** 3.17.1 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/reservation_test.rb`

```gherkin
Feature: Central System handles a rejected reservation
  Scenario: Rejected confirmation does not raise
    Given a pending outbound ReserveNow Message
    When the charge point responds with ReserveNow.conf status "Rejected"
    Then the Message status becomes "received" without error
```

### TC_049_CSMS — Reservation of a Charge Point (connectorId 0)
**Ref:** 3.17.2 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/reservation_test.rb`

```gherkin
Feature: Central System reserves the whole charge point rather than one connector
  Scenario: ReserveNow.req is sent with connectorId 0
    Given a connected charge point
    When the Central System enqueues a ReserveNow operation for the whole charge point
    Then the broadcast ReserveNow.req has connectorId 0
    And when the charge point sends StatusNotification.req status "Reserved", it is acknowledged
```

### TC_051_CSMS — Cancel Reservation
**Ref:** 3.17.3 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/reservation_test.rb`

```gherkin
Feature: Central System cancels an active reservation
  Background:
    Given a connector reserved with a known reservationId

  Scenario: CancelReservation.req references the right reservationId
    When the Central System enqueues a CancelReservation operation for that reservationId
    Then a CALL frame with action "CancelReservation" carrying that reservationId is broadcast

  Scenario: The connector reverts to Available after cancellation
    Given a pending outbound CancelReservation Message
    When the charge point responds with CancelReservation.conf status "Accepted"
    And then sends StatusNotification.req status "Available"
    Then both are acknowledged
```

### TC_052_CSMS — Cancel Reservation - Rejected
**Ref:** 3.17.3 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/reservation_test.rb`

```gherkin
Feature: Central System handles a rejected cancel-reservation request
  Scenario: Rejected confirmation does not raise
    Given a pending outbound CancelReservation Message
    When the charge point responds with CancelReservation.conf status "Rejected"
    Then the Message status becomes "received" without error
```

### TC_053_CSMS — Use a reserved Connector with parentIdTag
**Ref:** 3.17.4 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/reservation_test.rb`

```gherkin
Feature: A reservation made with a parentIdTag can be used by a matching idTag
  Scenario: ReserveNow.req carries both idTag and parentIdTag
    Given a connected charge point
    When the Central System enqueues a ReserveNow operation with an idTag and a parentIdTag
    Then the broadcast ReserveNow.req carries both fields

  Scenario: Charging with a different idTag sharing the parentIdTag succeeds
    Given the connector is reserved with that parentIdTag
    When the driver authorizes with a different idTag that shares the parentIdTag and starts a transaction
    Then StartTransaction.conf idTagInfo.status is "Accepted"
```

---

## 10. RemoteTrigger

### TC_054_CSMS — Trigger Message
**Ref:** 3.18.1 · **Status:** 🔴 Not implemented
**Gap:** No outbound `TriggerMessage` operation.
**Suggested file:** `test/ocpp/trigger_message_job_test.rb`

```gherkin
Feature: Central System triggers specific messages from the charge point
  Scenario Outline: Triggering a message and receiving it
    Given a connected charge point
    When the Central System enqueues a TriggerMessage operation for "<requestedMessage>"
    Then a CALL frame with action "TriggerMessage" and requestedMessage "<requestedMessage>" is broadcast
    And when the charge point responds with TriggerMessage.conf status "Accepted", the Message is recorded as received
    And when it subsequently sends the "<requestedMessage>" message, it is acknowledged

    Examples:
      | requestedMessage             |
      | MeterValues                  |
      | Heartbeat                    |
      | StatusNotification           |
      | DiagnosticsStatusNotification|

  Scenario: FirmwareStatusNotification trigger may be rejected as not implemented
    Given a connected charge point
    When the Central System enqueues a TriggerMessage operation for "FirmwareStatusNotification"
    Then when the charge point responds with status "Accepted" or "NotImplemented", the Message is recorded as received without error
```

### TC_055_CSMS — Trigger Message - Rejected
**Ref:** 3.18.2 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/trigger_message_job_test.rb`

```gherkin
Feature: Central System handles a rejected trigger request
  Scenario: Rejected confirmation does not raise
    Given a pending outbound TriggerMessage Message for "MeterValues"
    When the charge point responds with TriggerMessage.conf status "Rejected"
    Then the Message status becomes "received" without error
```

---

## 11. Smart Charging

### TC_056_CSMS — Central Smart Charging - TxDefaultProfile
**Ref:** 3.19.1 · **Status:** 🔴 Not implemented
**Gap:** No outbound `SetChargingProfile`/`ClearChargingProfile`/`GetCompositeSchedule` operations; no ChargingProfile model.
**Suggested file:** `test/ocpp/smart_charging_test.rb`

```gherkin
Feature: Central System sets a default charging schedule for future transactions
  Scenario: SetChargingProfile.req is sent with purpose TxDefaultProfile
    Given a connected charge point
    When the Central System enqueues a SetChargingProfile operation with chargingProfilePurpose "TxDefaultProfile", chargingProfileKind "Absolute", a validFrom, a validTo, and a chargingSchedule
    Then the broadcast SetChargingProfile.req omits transactionId and recurrencyKind
    And when the charge point responds with SetChargingProfile.conf status "Accepted", the Message is recorded as received
```

### TC_057_CSMS — Central Smart Charging - TxProfile
**Ref:** 3.19.1 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/smart_charging_test.rb`

```gherkin
Feature: Central System sets a schedule for a running transaction
  Background:
    Given an active charging session with a known transactionId

  Scenario: SetChargingProfile.req is sent with purpose TxProfile referencing the transaction
    When the Central System enqueues a SetChargingProfile operation with chargingProfilePurpose "TxProfile" and that transactionId
    Then the broadcast SetChargingProfile.req carries that transactionId and omits recurrencyKind
    And when the charge point responds with SetChargingProfile.conf status "Accepted", the Message is recorded as received

  Scenario Outline: Absolute vs Relative profile kind field requirements
    When the Central System enqueues a SetChargingProfile operation with chargingProfileKind "<kind>"
    Then the broadcast chargingSchedule.startSchedule is <startSchedulePresence>

    Examples:
      | kind     | startSchedulePresence |
      | Absolute | present                |
      | Relative | omitted                |
```

### TC_066_CSMS — Get Composite Schedule
**Ref:** 3.19.2 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/smart_charging_test.rb`

```gherkin
Feature: Central System requests the composite charging schedule
  Scenario: GetCompositeSchedule.req is sent with connectorId, duration, chargingRateUnit
    Given a connected charge point
    When the Central System enqueues a GetCompositeSchedule operation with a connectorId, duration, and chargingRateUnit
    Then a CALL frame with action "GetCompositeSchedule" carrying those fields is broadcast
    And when the charge point responds with GetCompositeSchedule.conf including a chargingSchedule, the Message is recorded as received
```

### TC_067_CSMS — Clear Charging Profile
**Ref:** 3.19.3 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/smart_charging_test.rb`

```gherkin
Feature: Central System clears charging profiles by id, by criteria, and entirely
  Background:
    Given three distinct charging profiles have been set: a ChargePointMaxProfile on connector 0, a TxDefaultProfile, and a TxProfile tied to a running transaction

  Scenario: Clear a profile by its id
    When the Central System enqueues a ClearChargingProfile operation with the id of the ChargePointMaxProfile
    Then the broadcast ClearChargingProfile.req carries only that id, with connectorId/purpose/stackLevel omitted
    And when the charge point responds with ClearChargingProfile.conf status "Accepted", the Message is recorded as received

  Scenario: Clear a profile by criteria
    When the Central System enqueues a ClearChargingProfile operation with connectorId, chargingProfilePurpose "TxDefaultProfile", and stackLevel
    Then the broadcast ClearChargingProfile.req omits id and carries those criteria fields
    And when the charge point responds with ClearChargingProfile.conf status "Accepted", the Message is recorded as received

  Scenario: Clear every remaining profile
    When the Central System enqueues a ClearChargingProfile operation with all fields omitted
    Then the broadcast ClearChargingProfile.req has an empty payload
    And when the charge point responds with ClearChargingProfile.conf status "Accepted", the Message is recorded as received
```

### TC_059_CSMS — Remote Start Transaction with Charging Profile
**Ref:** 3.19.4 · **Status:** 🔴 Not implemented
**Gap:** `RemoteStartTransactionJob` doesn't accept a `chargingProfile` argument today (it only sends `connectorId`/`idTag`).
**Suggested file:** `test/ocpp/smart_charging_test.rb`

```gherkin
Feature: Remote start includes a charging profile
  Scenario: RemoteStartTransaction.req carries a TxProfile with no transactionId
    Given a connected charge point
    When the Central System enqueues a RemoteStartTransaction operation with an idTag, connectorId, and a chargingProfile of purpose "TxProfile"
    Then the broadcast RemoteStartTransaction.req's chargingProfile omits transactionId
    And its chargingSchedule's first chargingSchedulePeriod has startPeriod 0

  Scenario: The subsequent session proceeds normally
    Given the charge point accepted the remote start with a charging profile
    When it sends Authorize.req, StatusNotification "Preparing", and StartTransaction.req for that idTag and connectorId
    Then each is accepted as in a normal remote-start flow
```

---

## 12. DataTransfer

### TC_064_CSMS — Data Transfer to a Central System
**Ref:** 3.20.1 · **Status:** 🔴 Not implemented
**Gap:** No inbound `DataTransferHandler`; an inbound DataTransfer.req currently gets a `NotSupported` CALLERROR instead of a proper DataTransfer.conf, which fails this case.
**Suggested file:** `test/ocpp/data_transfer_handler_test.rb`

```gherkin
Feature: Central System rejects data transfer for an unrecognized vendor
  Scenario: Unknown vendorId is rejected with a proper DataTransfer.conf
    Given no DataTransfer hook is registered for vendorId "Unrecognized.Vendor"
    When the charge point sends DataTransfer.req with vendorId "Unrecognized.Vendor"
    Then the Central System responds with DataTransfer.conf
    And its status is one of "Rejected", "UnknownMessageId", or "UnknownVendorId"
    And no CALLERROR is sent
```

---

## 13. Security (profiles 1–3)

All entries in this section require the Security feature profile, none of which is
implemented today — only OCPP-J Security Profile 1 (HTTP Basic Auth on connect)
exists. TLS (profile 2/3) is expected to terminate in front of the Rails app.

### TC_073_CSMS — Update Charge Point Password for HTTP Basic Authentication
**Ref:** 3.21.1 · **Status:** 🔴 Not implemented
**Gap:** requires the (unimplemented) outbound `ChangeConfiguration` plus password-rotation handling.
**Suggested file:** `test/ocpp/security/update_password_test.rb`

```gherkin
Feature: Central System rotates the station's Basic Auth password
  Scenario: ChangeConfiguration.req updates the AuthorizationKey
    Given a connected charge point authenticated with its current password
    When the Central System enqueues a ChangeConfiguration operation for key "AuthorizationKey" with a new hex-encoded password between 16 and 20 bytes
    Then the broadcast ChangeConfiguration.req carries that key and value
    And when the charge point responds with ChangeConfiguration.conf status "Accepted", the Message is recorded as received

  Scenario: The charge point reconnects with the new password
    Given the password has been changed
    When the charge point disconnects and reconnects using the new password
    Then the connection is authenticated successfully
```

### TC_074_CSMS — Update Charge Point Certificate by request of Central System
**Ref:** 3.21.1 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/security/certificate_renewal_test.rb`

```gherkin
Feature: Central System triggers certificate renewal and signs the CSR
  Scenario: ExtendedTriggerMessage requests a new certificate
    Given a connected charge point supporting security profile 3
    When the Central System enqueues an ExtendedTriggerMessage operation for "SignChargePointCertificate"
    Then the broadcast ExtendedTriggerMessage.req omits connectorId

  Scenario: SignCertificate.req is accepted
    Given the charge point generated a CSR
    When it sends SignCertificate.req
    Then the Central System responds with SignCertificate.conf status "Accepted"

  Scenario: CertificateSigned.req carries a valid certificate chain
    Given the CSR has been signed by the (test) certificate authority
    When the Central System sends CertificateSigned.req
    Then the certificateChain is valid PEM
    And its public key matches the CSR's public key
    And the subject commonName equals the configured serialNumber
    And the key length meets the OCPP minimum (RSA >= 2048 / ECDSA >= 224)
```

### TC_075_1_CSMS / TC_075_2_CSMS — Install a certificate (Manufacturer / CentralSystem root)
**Ref:** 3.21.1 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/security/install_certificate_test.rb`

```gherkin
Feature: Central System installs a root certificate on the charge point
  Scenario Outline: InstallCertificate.req is sent for a given certificateType
    Given a connected charge point supporting security profile 2 or 3
    When the Central System enqueues an InstallCertificate operation with certificateType "<certificateType>" and a root certificate
    Then the broadcast InstallCertificate.req carries that certificateType and certificate
    And when the charge point responds with InstallCertificate.conf status "Accepted", the Message is recorded as received

    Examples:
      | certificateType              |
      | ManufacturerRootCertificate  |
      | CentralSystemRootCertificate |

  Scenario: GetInstalledCertificateIds confirms the installation
    Given the certificate above was installed
    When the Central System enqueues a GetInstalledCertificateIds operation for that certificateType
    Then the charge point's response includes certificateHashData matching the installed certificate
```

### TC_076_CSMS — Delete a specific certificate from the Charge Point
**Ref:** 3.21.1 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/security/delete_certificate_test.rb`

```gherkin
Feature: Central System deletes an installed certificate
  Background:
    Given a CentralSystemRootCertificate has been installed and its certificateHashData retrieved

  Scenario Outline: DeleteCertificate.req is sent with matching hash data
    When the Central System enqueues a DeleteCertificate operation using hashAlgorithm "<hashAlgorithm>" and the retrieved certificateHashData
    Then the broadcast DeleteCertificate.req's certificateHashData matches the one from GetInstalledCertificateIds
    And when the charge point responds with DeleteCertificate.conf status "Accepted", the Message is recorded as received

    Examples:
      | hashAlgorithm |
      | SHA256        |
      | SHA384        |
      | SHA512        |
```

### TC_077_CSMS — Invalid ChargePointCertificate Security Event
**Ref:** 3.21.2 · **Status:** 🔴 Not implemented
**Gap:** No inbound `SecurityEventNotification` handler.
**Suggested file:** `test/ocpp/security/security_event_test.rb`

```gherkin
Feature: Central System handles a rejected certificate and the resulting security event
  Scenario: CertificateSigned.conf is Rejected and a SecurityEventNotification follows
    Given a certificate renewal in progress
    When the Central System deems the CertificateSigned.req invalid and the charge point responds Rejected
    And the charge point sends SecurityEventNotification.req with type "InvalidChargePointCertificate"
    Then the Central System responds with SecurityEventNotification.conf
```

### TC_078_CSMS — Invalid CentralSystemCertificate Security Event
**Ref:** 3.21.2 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/security/security_event_test.rb`

```gherkin
Feature: Central System handles a rejected root certificate install and the resulting security event
  Scenario: InstallCertificate.conf is Rejected and a SecurityEventNotification follows
    Given the Central System enqueued an InstallCertificate operation for a CentralSystemRootCertificate
    When the charge point rejects it and sends SecurityEventNotification.req with type "InvalidCentralSystemCertificate"
    Then the Central System responds with SecurityEventNotification.conf
```

### TC_079_CSMS — Get Security Log
**Ref:** 3.21.2 · **Status:** 🔴 Not implemented
**Gap:** No outbound `GetLog` operation and no inbound `LogStatusNotification` handler.
**Suggested file:** `test/ocpp/security/get_log_test.rb`

```gherkin
Feature: Central System retrieves the security log
  Scenario: GetLog.req requests the SecurityLog
    Given a connected charge point supporting a security profile
    When the Central System enqueues a GetLog operation with logType "SecurityLog" and a remote location
    Then a CALL frame with action "GetLog" carrying that logType and location is broadcast

  Scenario: Upload progress is acknowledged
    Given a pending outbound GetLog Message
    When the charge point sends LogStatusNotification.req status "Uploading" then "Uploaded"
    Then each is acknowledged with LogStatusNotification.conf
```

### TC_080_CSMS — Secure Firmware Update
**Ref:** 3.21.3 · **Status:** 🔴 Not implemented
**Gap:** No outbound `SignedUpdateFirmware` operation and no inbound `SignedFirmwareStatusNotification` handler.
**Suggested file:** `test/ocpp/security/signed_firmware_update_test.rb`

```gherkin
Feature: Central System triggers a signed firmware update
  Scenario: SignedUpdateFirmware.req carries location, signature, and signingCertificate
    Given a connected charge point supporting Firmware Management and a security profile
    When the Central System enqueues a SignedUpdateFirmware operation with a location, signature, and signingCertificate
    Then a CALL frame with action "SignedUpdateFirmware" carrying those fields is broadcast

  Scenario: The full signed status progression is acknowledged
    Given a pending outbound SignedUpdateFirmware Message
    When the charge point sends SignedFirmwareStatusNotification.req with status "Downloading", "Downloaded", "SignatureVerified", "Installing", "InstallRebooting", and finally "Installed"
    Then each is acknowledged with SignedFirmwareStatusNotification.conf

  Scenario: A FirmwareUpdated security event is logged after reboot
    Given the charge point rebooted and sent a new BootNotification.req
    When it sends SecurityEventNotification.req with type "FirmwareUpdated"
    Then the Central System responds with SecurityEventNotification.conf
```

### TC_081_CSMS — Secure Firmware Update - Invalid Signature
**Ref:** 3.21.3 · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/security/signed_firmware_update_test.rb`

```gherkin
Feature: Central System handles a firmware signature the charge point rejects
  Scenario: InvalidSignature status is acknowledged
    Given a pending outbound SignedUpdateFirmware Message with a deliberately invalid signature
    When the charge point sends SignedFirmwareStatusNotification.req status "Downloading" then "Downloaded" then "InvalidSignature"
    Then each is acknowledged with SignedFirmwareStatusNotification.conf
```

### TC_083_CSMS — Upgrade Charge Point Security Profile - Accepted
**Ref:** 3.21 (table 189) · **Status:** 🔴 Not implemented
**Suggested file:** `test/ocpp/security/upgrade_security_profile_test.rb`

```gherkin
Feature: Central System upgrades the station to a higher security profile
  Scenario: ChangeConfiguration raises the SecurityProfile then a Hard Reset applies it
    Given a charge point currently on security profile 1 with a certificate already installed
    When the Central System enqueues a ChangeConfiguration operation for key "SecurityProfile" value "2"
    And the charge point responds with ChangeConfiguration.conf status "Accepted"
    And the Central System then enqueues a Reset operation with type "Hard"
    Then when the charge point reboots, BootNotification.conf status is "Accepted"
    And subsequent StatusNotification.req messages for each connector are acknowledged
```

### TC_085_CSMS — Basic Authentication - Valid username/password combination
**Ref:** 3.21 (table 190) · **Status:** ✅ Implemented + tested
**Existing coverage:** `test/ocpp/station_authentication_test.rb` (`ChannelAuthenticationTest`) asserts that a station presenting valid HTTP Basic credentials is accepted and streams for its charge point, and that wrong/missing/cross-identity credentials are rejected. The follow-on BootNotification/StatusNotification sequence after a successful connect is not asserted in the same test.
**Suggested file:** `test/ocpp/station_authentication_test.rb` (extend)

```gherkin
Feature: A station with valid Basic Auth credentials completes registration
  Scenario: Connection is authenticated and boot proceeds normally
    Given a charge point with a configured auth password
    When it connects using HTTP Basic Auth with its identifier and correct password
    Then the subscription is confirmed and streams for that charge point
    And when it sends BootNotification.req, BootNotification.conf status is "Accepted"
    And subsequent StatusNotification.req messages per connector are acknowledged
```

### TC_086_CSMS / TC_087_CSMS — TLS server-side / client-side certificate
**Ref:** 3.21 (tables 191–192) · **Status:** ⚪ Out of scope
**Rationale:** TLS termination (cipher-suite selection, certificate presentation, client-cert verification) happens at the reverse proxy / load balancer in front of this Rails engine, not in application code. There's nothing for `ocpp-rails` unit/integration tests to exercise here; this belongs in the deployment's infrastructure test suite instead.
