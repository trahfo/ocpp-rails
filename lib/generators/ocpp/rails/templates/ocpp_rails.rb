Ocpp::Rails.setup do |config|
  # Default OCPP version to use
  config.ocpp_version = "1.6"

  # Supported OCPP versions
  config.supported_versions = ["1.6", "2.0", "2.0.1", "2.1"]

  # Heartbeat interval in seconds
  config.heartbeat_interval = 300

  # Connection timeout in seconds
  config.connection_timeout = 30
end
