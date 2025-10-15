# frozen_string_literal: true

module OcppTestHelper
  # Creates a test charge point
  def create_charge_point(attributes = {})
    defaults = {
      identifier: "CP_#{SecureRandom.hex(4)}",
      vendor: "Test Vendor",
      model: "Test Model v1",
      serial_number: "SN#{SecureRandom.hex(6)}",
      firmware_version: "1.0.0",
      ocpp_protocol: "1.6",
      status: "Available",
      connected: true,
      last_heartbeat_at: Time.current
    }
    Ocpp::Rails::ChargePoint.create!(defaults.merge(attributes))
  end

  # Creates a test charging session
  def create_charging_session(charge_point, attributes = {})
    defaults = {
      connector_id: 1,
      transaction_id: SecureRandom.uuid,
      id_tag: "RFID#{SecureRandom.hex(4)}",
      status: "Preparing",
      started_at: Time.current,
      start_meter_value: 0
    }
    charge_point.charging_sessions.create!(defaults.merge(attributes))
  end

  # Creates a test meter value
  def create_meter_value(charge_point, charging_session = nil, attributes = {})
    defaults = {
      connector_id: 1,
      measurand: "Energy.Active.Import.Register",
      unit: "Wh",
      value: rand(1000..50000),
      timestamp: Time.current,
      context: "Sample.Periodic"
    }

    params = defaults.merge(attributes)
    params[:charging_session_id] = charging_session&.id if charging_session

    Ocpp::Rails::MeterValue.create!(params.merge(charge_point: charge_point))
  end

  # OCPP Message Builders

  # Builds a BootNotification request
  def build_boot_notification_request(charge_point_vendor: "Test Vendor", charge_point_model: "Test Model")
    {
      chargePointVendor: charge_point_vendor,
      chargePointModel: charge_point_model,
      chargePointSerialNumber: "SN#{SecureRandom.hex(6)}",
      firmwareVersion: "1.0.0",
      iccid: "89014104277001122334",
      imsi: "310410123456789",
      meterType: "Test Meter",
      meterSerialNumber: "MSN#{SecureRandom.hex(6)}"
    }
  end

  # Builds a BootNotification response
  def build_boot_notification_response(status: "Accepted", interval: 300)
    {
      status: status,
      currentTime: Time.current.iso8601,
      interval: interval
    }
  end

  # Builds a Heartbeat request
  def build_heartbeat_request
    {}
  end

  # Builds a Heartbeat response
  def build_heartbeat_response
    {
      currentTime: Time.current.iso8601
    }
  end

  # Builds an Authorize request
  def build_authorize_request(id_tag: "RFID#{SecureRandom.hex(4)}")
    {
      idTag: id_tag
    }
  end

  # Builds an Authorize response
  def build_authorize_response(status: "Accepted")
    {
      idTagInfo: {
        status: status,
        expiryDate: (Time.current + 1.year).iso8601
      }
    }
  end

  # Builds a StartTransaction request
  def build_start_transaction_request(connector_id: 1, id_tag: "RFID#{SecureRandom.hex(4)}", meter_start: 0)
    {
      connectorId: connector_id,
      idTag: id_tag,
      meterStart: meter_start,
      timestamp: Time.current.iso8601
    }
  end

  # Builds a StartTransaction response
  def build_start_transaction_response(transaction_id: 1, status: "Accepted")
    {
      transactionId: transaction_id,
      idTagInfo: {
        status: status
      }
    }
  end

  # Builds a StopTransaction request
  def build_stop_transaction_request(transaction_id:, meter_stop:, reason: "Local")
    {
      transactionId: transaction_id.to_s,
      meterStop: meter_stop,
      timestamp: Time.current.iso8601,
      reason: reason
    }
  end

  # Builds a StopTransaction response
  def build_stop_transaction_response(status: "Accepted")
    {
      idTagInfo: {
        status: status
      }
    }
  end

  # Builds a MeterValues request
  def build_meter_values_request(connector_id: 1, transaction_id: nil, meter_values: [])
    request = {
      connectorId: connector_id,
      meterValue: meter_values.presence || [build_meter_value]
    }
    request[:transactionId] = transaction_id if transaction_id
    request
  end

  # Builds a single meter value
  def build_meter_value(timestamp: Time.current, values: nil)
    {
      timestamp: timestamp.iso8601,
      sampledValue: values || [
        {
          value: "12345",
          context: "Sample.Periodic",
          measurand: "Energy.Active.Import.Register",
          unit: "Wh"
        }
      ]
    }
  end

  # Builds a StatusNotification request
  def build_status_notification_request(connector_id: 1, status: "Available", error_code: "NoError")
    {
      connectorId: connector_id,
      status: status,
      errorCode: error_code,
      timestamp: Time.current.iso8601
    }
  end

  # Builds a DataTransfer request
  def build_data_transfer_request(vendor_id: "TestVendor", message_id: nil, data: nil)
    request = { vendorId: vendor_id }
    request[:messageId] = message_id if message_id
    request[:data] = data if data
    request
  end

  # Builds a DataTransfer response
  def build_data_transfer_response(status: "Accepted", data: nil)
    response = { status: status }
    response[:data] = data if data
    response
  end

  # Builds a RemoteStartTransaction request
  def build_remote_start_transaction_request(id_tag:, connector_id: nil, charging_profile: nil)
    request = { idTag: id_tag }
    request[:connectorId] = connector_id if connector_id
    request[:chargingProfile] = charging_profile if charging_profile
    request
  end

  # Builds a RemoteStopTransaction request
  def build_remote_stop_transaction_request(transaction_id:)
    { transactionId: transaction_id.to_s }
  end

  # Builds a ChangeConfiguration request
  def build_change_configuration_request(key:, value:)
    { key: key, value: value }
  end

  # Builds a Reset request
  def build_reset_request(type: "Soft")
    { type: type }
  end

  # Builds a ChangeAvailability request
  def build_change_availability_request(connector_id:, type:)
    { connectorId: connector_id, type: type }
  end

  # Builds a ReserveNow request
  def build_reserve_now_request(connector_id:, expiry_date:, id_tag:, reservation_id:)
    {
      connectorId: connector_id,
      expiryDate: expiry_date.iso8601,
      idTag: id_tag,
      reservationId: reservation_id
    }
  end

  # Builds a CancelReservation request
  def build_cancel_reservation_request(reservation_id:)
    { reservationId: reservation_id }
  end

  # Builds a SetChargingProfile request
  def build_set_charging_profile_request(connector_id:, cs_charging_profiles:)
    {
      connectorId: connector_id,
      csChargingProfiles: cs_charging_profiles
    }
  end

  # Builds a charging profile
  def build_charging_profile(profile_id:, stack_level: 0, purpose: "TxDefaultProfile", kind: "Absolute")
    {
      chargingProfileId: profile_id,
      stackLevel: stack_level,
      chargingProfilePurpose: purpose,
      chargingProfileKind: kind,
      chargingSchedule: {
        chargingRateUnit: "W",
        chargingSchedulePeriod: [
          { startPeriod: 0, limit: 11000 }
        ]
      }
    }
  end

  # Builds a ClearChargingProfile request
  def build_clear_charging_profile_request(id: nil, connector_id: nil, purpose: nil, stack_level: nil)
    request = {}
    request[:id] = id if id
    request[:connectorId] = connector_id if connector_id
    request[:chargingProfilePurpose] = purpose if purpose
    request[:stackLevel] = stack_level if stack_level
    request
  end

  # Builds an UnlockConnector request
  def build_unlock_connector_request(connector_id:)
    { connectorId: connector_id }
  end

  # Builds a GetDiagnostics request
  def build_get_diagnostics_request(location:, retries: 3, retry_interval: 60)
    {
      location: location,
      retries: retries,
      retryInterval: retry_interval
    }
  end

  # Builds an UpdateFirmware request
  def build_update_firmware_request(location:, retrieve_date:, retries: 3, retry_interval: 60)
    {
      location: location,
      retrieveDate: retrieve_date.iso8601,
      retries: retries,
      retryInterval: retry_interval
    }
  end

  # Builds a SendLocalList request
  def build_send_local_list_request(list_version:, update_type:, local_authorization_list: [])
    {
      listVersion: list_version,
      updateType: update_type,
      localAuthorizationList: local_authorization_list
    }
  end

  # Builds a GetLocalListVersion request
  def build_get_local_list_version_request
    {}
  end

  # Builds a TriggerMessage request
  def build_trigger_message_request(requested_message:, connector_id: nil)
    request = { requestedMessage: requested_message }
    request[:connectorId] = connector_id if connector_id
    request
  end

  # OCPP Message Frame Builders (for WebSocket testing)

  # Builds a CALL message frame
  def build_call_message(action:, payload:, message_id: nil)
    message_id ||= SecureRandom.uuid
    [2, message_id, action, payload]
  end

  # Builds a CALLRESULT message frame
  def build_callresult_message(message_id:, payload:)
    [3, message_id, payload]
  end

  # Builds a CALLERROR message frame
  def build_callerror_message(message_id:, error_code:, error_description:, error_details: {})
    [4, message_id, error_code, error_description, error_details]
  end

  # Parses an OCPP message from JSON
  def parse_ocpp_message(json_string)
    JSON.parse(json_string)
  end

  # Asserts OCPP message structure
  def assert_valid_call_message(message)
    assert_equal 2, message[0], "Message type should be CALL (2)"
    assert_kind_of String, message[1], "Message ID should be a string"
    assert_kind_of String, message[2], "Action should be a string"
    assert_kind_of Hash, message[3], "Payload should be a hash"
  end

  def assert_valid_callresult_message(message)
    assert_equal 3, message[0], "Message type should be CALLRESULT (3)"
    assert_kind_of String, message[1], "Message ID should be a string"
    assert_kind_of Hash, message[2], "Payload should be a hash"
  end

  def assert_valid_callerror_message(message)
    assert_equal 4, message[0], "Message type should be CALLERROR (4)"
    assert_kind_of String, message[1], "Message ID should be a string"
    assert_kind_of String, message[2], "Error code should be a string"
    assert_kind_of String, message[3], "Error description should be a string"
  end

  # Error codes
  OCPP_ERROR_CODES = {
    not_implemented: "NotImplemented",
    not_supported: "NotSupported",
    internal_error: "InternalError",
    protocol_error: "ProtocolError",
    security_error: "SecurityError",
    formation_violation: "FormationViolation",
    property_constraint_violation: "PropertyConstraintViolation",
    occurence_constraint_violation: "OccurenceConstraintViolation",
    type_constraint_violation: "TypeConstraintViolation",
    generic_error: "GenericError"
  }.freeze

  # Status values
  REGISTRATION_STATUS = %w[Accepted Pending Rejected].freeze
  AUTHORIZATION_STATUS = %w[Accepted Blocked Expired Invalid ConcurrentTx].freeze
  CHARGE_POINT_STATUS = %w[Available Preparing Charging SuspendedEVSE SuspendedEV Finishing Reserved Unavailable Faulted].freeze
  CHARGE_POINT_ERROR_CODE = %w[ConnectorLockFailure EVCommunicationError GroundFailure HighTemperature InternalError LocalListConflict NoError OtherError OverCurrentFailure PowerMeterFailure PowerSwitchFailure ReaderFailure ResetFailure UnderVoltage OverVoltage WeakSignal].freeze
end
