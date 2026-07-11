module Ocpp
  module Rails
    module SessionHookManager
      EVENTS = [ "started", "stopped" ].freeze

      def self.execute_hooks(charging_session, event)
        hooks = Ocpp::Rails.configuration.session_hooks

        hooks.each do |hook|
          begin
            if hook.respond_to?(:async?) && hook.async?
              # Enqueue async hook job
              Ocpp::Rails::SessionAsyncHookJob.perform_later(charging_session.id, event, hook.class.name)
            else
              # Execute synchronously
              hook.call(charging_session, event)
            end
          rescue => error
            ::Rails.logger.error("SessionHook #{hook.class.name} failed: #{error.message}")
            ::Rails.logger.error(error.backtrace.join("\n"))
          end
        end

        true
      end
    end
  end
end
