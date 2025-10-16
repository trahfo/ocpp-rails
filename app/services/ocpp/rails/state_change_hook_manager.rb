module Ocpp
  module Rails
    module StateChangeHookManager
      def self.execute_hooks(state_change)
        hooks = Ocpp::Rails.configuration.state_change_hooks

        hooks.each do |hook|
          begin
            if hook.respond_to?(:async?) && hook.async?
              # Enqueue async hook job
              Ocpp::Rails::AsyncHookJob.perform_later(state_change.id, hook.class.name)
            else
              # Execute synchronously
              hook.call(state_change)
            end
          rescue => error
            ::Rails.logger.error("StateChangeHook #{hook.class.name} failed: #{error.message}")
            ::Rails.logger.error(error.backtrace.join("\n"))
          end
        end

        true
      end
    end
  end
end
