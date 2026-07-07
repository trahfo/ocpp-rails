module Ocpp
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace Ocpp::Rails

      config.generators.api_only = true

      # Configure ActionCable to use the async adapter (works with SQLite)
      # This is suitable for development, testing, and single-server deployments
      # For production with multiple servers, use Redis or PostgreSQL adapter.
      # An existing config/cable.yml always takes precedence.
      initializer "ocpp_rails.action_cable", before: "actioncable.set_configs" do |app|
        if (::Rails.env.development? || ::Rails.env.test?) && !app.root.join("config/cable.yml").exist?
          app.config.action_cable.cable ||= { "adapter" => "async" }
        end
      end
    end
  end
end
