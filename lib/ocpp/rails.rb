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
      attr_accessor :ocpp_version, :supported_versions, :heartbeat_interval, :connection_timeout

      def initialize
        @ocpp_version = "1.6"
        @supported_versions = ["1.6", "2.0", "2.0.1", "2.1"]
        @heartbeat_interval = 300
        @connection_timeout = 30
      end
    end
  end
end
