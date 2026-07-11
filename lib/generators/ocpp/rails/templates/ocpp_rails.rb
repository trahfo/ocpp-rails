Ocpp::Rails.setup do |config|
  # Default OCPP version to use
  config.ocpp_version = "1.6"

  # Supported OCPP versions (only 1.6 is implemented)
  config.supported_versions = [ "1.6" ]

  # Heartbeat interval in seconds
  config.heartbeat_interval = 300

  # Connection timeout in seconds
  config.connection_timeout = 30

  # Session lifecycle hooks: objects responding to
  # call(charging_session, event) with event "started" or "stopped".
  # Define async? => true on a hook to run it via ActiveJob instead of
  # inline. Example:
  #
  #   config.register_session_hook(MySessionHook.new)
end
