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

    class Configuration
      attr_accessor :ocpp_version, :supported_versions, :heartbeat_interval, :connection_timeout,
                    :state_change_hooks, :state_change_retention_days, :state_change_cleanup_enabled,
                    :authorization_hooks, :authorization_retention_days, :authorization_cleanup_enabled,
                    :implausible_energy_jump_wh

      def initialize
        @ocpp_version = "1.6"
        # Only 1.6 is implemented; expand when 2.x support lands.
        @supported_versions = ["1.6"]
        @heartbeat_interval = 300
        @connection_timeout = 30
        @state_change_hooks = []
        @authorization_hooks = []
        @state_change_retention_days = 30
        @state_change_cleanup_enabled = true
        @authorization_retention_days = 30
        @authorization_cleanup_enabled = true
        # Max plausible energy register increase between samples, in Wh;
        # readings jumping further are flagged. nil disables the check.
        @implausible_energy_jump_wh = 1_000_000
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
    end
  end
end
