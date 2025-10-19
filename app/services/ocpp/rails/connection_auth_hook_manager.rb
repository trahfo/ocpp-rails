module Ocpp
  module Rails
    module ConnectionAuthHookManager
      def self.execute_hooks(username, password, charge_point_id)
        hooks = Ocpp::Rails.configuration.connection_auth_hooks
        sync_hooks = hooks.reject { |hook| hook.respond_to?(:async?) && hook.async? }

        # Fail-secure: If no sync hooks registered, reject connection
        if sync_hooks.empty?
          ::Rails.logger.info("No connection auth hooks registered, rejecting connection")
          return false
        end

        # Execute sync hooks sequentially in registration order
        sync_hooks.each do |hook|
          begin
            result = hook.call(username, password, charge_point_id)

            # Validate return value is boolean
            unless result == true || result == false
              ::Rails.logger.error("ConnectionAuthHook #{hook.class.name} returned non-boolean: #{result.inspect}")
              return false
            end

            # If hook rejects, return false immediately
            if result == false
              ::Rails.logger.info("ConnectionAuthHook #{hook.class.name} rejected connection")
              return false
            end

            # If result is true, continue to next hook
          rescue => error
            ::Rails.logger.error("ConnectionAuthHook #{hook.class.name} raised exception: #{error.message}")
            ::Rails.logger.error(error.backtrace.join("\n"))
            return false
          end
        end

        # All sync hooks returned true
        true
      end

      def self.execute_async_hooks(username, password, charge_point_id)
        hooks = Ocpp::Rails.configuration.connection_auth_hooks
        async_hooks = hooks.select { |hook| hook.respond_to?(:async?) && hook.async? }

        async_hooks.each do |hook|
          begin
            Ocpp::Rails::ConnectionAuthAsyncHookJob.perform_later(username, password, charge_point_id, hook.class.name)
          rescue => error
            ::Rails.logger.error("Failed to enqueue ConnectionAuthAsyncHookJob for #{hook.class.name}: #{error.message}")
          end
        end

        true
      end
    end
  end
end
