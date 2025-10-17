module Ocpp
  module Rails
    module AuthorizationHookManager
      VALID_STATUSES = ["Accepted", "Blocked", "Expired", "Invalid", "ConcurrentTx"].freeze
      DEFAULT_EXPIRY = 1.year

      def self.execute_hooks(charge_point_id, id_tag)
        hooks = Ocpp::Rails.configuration.authorization_hooks
        sync_hooks = hooks.reject { |hook| hook.respond_to?(:async?) && hook.async? }

        # If no sync hooks, default to accepted
        if sync_hooks.empty?
          return {
            status: "Accepted",
            expiry_date: Time.current + DEFAULT_EXPIRY
          }
        end

        # Execute sync hooks
        expiry_dates = []

        sync_hooks.each do |hook|
          begin
            result = hook.call(charge_point_id, id_tag)

            # Validate return value
            unless result.is_a?(Hash)
              ::Rails.logger.error("AuthorizationHook #{hook.class.name} returned non-hash: #{result.inspect}")
              return { status: "Invalid", expiry_date: nil }
            end

            # Normalize keys to strings
            result = result.stringify_keys

            # Validate status key exists
            unless result.key?("status")
              ::Rails.logger.error("AuthorizationHook #{hook.class.name} returned hash without status key: #{result.inspect}")
              return { status: "Invalid", expiry_date: nil }
            end

            status = result["status"]

            # Validate status value
            unless VALID_STATUSES.include?(status)
              ::Rails.logger.error("AuthorizationHook #{hook.class.name} returned invalid status: #{status}")
              return { status: "Invalid", expiry_date: nil }
            end

            # If rejected, return immediately
            if status != "Accepted"
              ::Rails.logger.info("AuthorizationHook #{hook.class.name} rejected with status: #{status}")
              return { status: status, expiry_date: nil }
            end

            # If accepted, collect expiry date
            if result["expiry_date"].present?
              expiry_dates << parse_expiry_date(result["expiry_date"])
            end
          rescue => error
            ::Rails.logger.error("AuthorizationHook #{hook.class.name} raised exception: #{error.message}")
            ::Rails.logger.error(error.backtrace.join("\n"))
            return { status: "Invalid", expiry_date: nil }
          end
        end

        # All hooks accepted, return with latest expiry
        {
          status: "Accepted",
          expiry_date: expiry_dates.max || (Time.current + DEFAULT_EXPIRY)
        }
      end

      def self.execute_async_hooks(authorization)
        hooks = Ocpp::Rails.configuration.authorization_hooks
        async_hooks = hooks.select { |hook| hook.respond_to?(:async?) && hook.async? }

        async_hooks.each do |hook|
          begin
            Ocpp::Rails::AuthorizationAsyncHookJob.perform_later(authorization.id, hook.class.name)
          rescue => error
            ::Rails.logger.error("Failed to enqueue AuthorizationAsyncHookJob for #{hook.class.name}: #{error.message}")
          end
        end

        true
      end

      private

      def self.parse_expiry_date(expiry_date)
        return expiry_date if expiry_date.is_a?(Time) || expiry_date.is_a?(DateTime) || expiry_date.is_a?(ActiveSupport::TimeWithZone)

        begin
          Time.parse(expiry_date.to_s)
        rescue
          ::Rails.logger.error("Failed to parse expiry_date: #{expiry_date.inspect}, using default")
          Time.current + DEFAULT_EXPIRY
        end
      end
    end
  end
end
