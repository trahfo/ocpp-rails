Ocpp::Rails.setup do |config|
  # Default OCPP version to use
  config.ocpp_version = "1.6"

  # Supported OCPP versions (only 1.6 is implemented)
  config.supported_versions = [ "1.6" ]

  # Heartbeat interval in seconds
  config.heartbeat_interval = 300

  # Connection timeout in seconds
  config.connection_timeout = 30
end
