module Ocpp
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace Ocpp::Rails

      config.generators.api_only = true

      # Configure ActionCable to use async adapter (works with SQLite)
      # This is suitable for development, testing, and single-server deployments
      # For production with multiple servers, use Redis or PostgreSQL adapter
      initializer "ocpp_rails.action_cable", before: "actioncable.set_configs" do |app|
        app.config.action_cable.adapter ||= :async if ::Rails.env.development? || ::Rails.env.test?
      end
    end
  end
end
