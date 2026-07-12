require "ocpp/rails/version"
require "ocpp/rails/engine"

module Ocpp
  module Rails
    class << self
      attr_accessor :configuration
    end

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.setup
      yield(configuration)
    end

    def self.supported_versions
      configuration.supported_versions
    end

    # Whether a given charge-point transport is active. `transport` is one of
    # :action_cable (default), :raw, or :both — so a deployment can run the
    # legacy ActionCable-wrapped endpoint, the raw OCPP-J endpoint, or both side
    # by side during migration. Consulted when the engine draws its routes.
    def self.transport_enabled?(kind)
      transport = configuration.transport
      transport == kind || transport == :both
    end

    def self.message_rate_limiter
      @message_rate_limiter ||= RateLimiter.new { configuration.max_messages_per_minute }
    end

    def self.connection_rate_limiter
      @connection_rate_limiter ||= RateLimiter.new { configuration.max_connection_attempts_per_minute }
    end

    def self.reset_rate_limiters!
      @message_rate_limiter&.reset!
      @connection_rate_limiter&.reset!
    end

    class Configuration
      attr_accessor :ocpp_version, :supported_versions, :heartbeat_interval, :connection_timeout,
                    :state_change_hooks, :state_change_retention_days, :state_change_cleanup_enabled,
                    :authorization_hooks, :authorization_retention_days, :authorization_cleanup_enabled,
                    :session_hooks, :implausible_energy_jump_wh, :authentication_mode,
                    :max_messages_per_minute, :max_connection_attempts_per_minute,
                    :transport, :raw_socket_path, :websocket_subprotocols, :raw_socket_max_frame_bytes

      def initialize
        @ocpp_version = "1.6"
        # Only 1.6 is implemented; expand when 2.x support lands.
        @supported_versions = [ "1.6" ]
        @heartbeat_interval = 300
        @connection_timeout = 30
        @state_change_hooks = []
        @authorization_hooks = []
        @session_hooks = []
        @state_change_retention_days = 30
        @state_change_cleanup_enabled = true
        @authorization_retention_days = 30
        @authorization_cleanup_enabled = true
        # Max plausible energy register increase between samples, in Wh;
        # readings jumping further are flagged. nil disables the check.
        @implausible_energy_jump_wh = 1_000_000
        # :basic (OCPP-J Security Profile 1, HTTP Basic Auth) or :none.
        # :none accepts any client that knows a station identifier - only
        # for closed networks or during migration.
        @authentication_mode = :basic
        # Per-station ingress limits (fixed 60s windows, per process);
        # nil disables the respective check.
        @max_messages_per_minute = 300
        @max_connection_attempts_per_minute = 12
        # Charge-point transport. :action_cable (default; ActionCable-wrapped
        # OCPP-J, backwards compatible) | :raw (native bare OCPP-J over a plain
        # WebSocket, what real stations speak) | :both (run both endpoints).
        @transport = :action_cable
        # Where the raw OCPP-J endpoint is mounted *within the engine*. With the
        # host app mounting the engine at "/ocpp", the default "/" makes a station
        # connect to ws://host/ocpp/<identifier> (the trailing path segment is the
        # OCPP identity). "/cable" stays reserved for the ActionCable endpoint.
        @raw_socket_path = "/"
        # Subprotocols offered back to a raw station, in server-preference order.
        # OCPP 1.6-J stations send "ocpp1.6"; the negotiated value is echoed in
        # the handshake's Sec-WebSocket-Protocol response header.
        @websocket_subprotocols = [ "ocpp1.6", "ocpp1.6j" ]
        # Max inbound WebSocket message size on the raw endpoint (bytes). OCPP-J
        # messages are small; oversized frames are a DoS vector and are refused.
        @raw_socket_max_frame_bytes = 64 * 1024
      end

      def register_state_change_hook(hook)
        unless hook.respond_to?(:call)
          raise ArgumentError, "Hook must respond to :call method"
        end
        @state_change_hooks << hook
      end

      def register_authorization_hook(hook)
        unless hook.respond_to?(:call)
          raise ArgumentError, "Hook must respond to :call method"
        end
        @authorization_hooks << hook
      end

      def register_session_hook(hook)
        unless hook.respond_to?(:call)
          raise ArgumentError, "Hook must respond to :call method"
        end
        @session_hooks << hook
      end
    end
  end
end
