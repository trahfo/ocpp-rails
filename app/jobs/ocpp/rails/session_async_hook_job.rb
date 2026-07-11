module Ocpp
  module Rails
    class SessionAsyncHookJob < ApplicationJob
      queue_as :ocpp_hooks

      retry_on StandardError, wait: :polynomially_longer, attempts: 3

      def perform(charging_session_id, event, hook_class_name)
        charging_session = Ocpp::Rails::ChargingSession.find_by(id: charging_session_id)

        unless charging_session
          ::Rails.logger.warn("ChargingSession #{charging_session_id} not found, may have been cleaned up")
          return
        end

        hook_class = hook_class_name.constantize
        hook = hook_class.new
        hook.call(charging_session, event)
      rescue => error
        ::Rails.logger.error("SessionAsyncHook #{hook_class_name} failed for ChargingSession #{charging_session_id} (#{event}): #{error.message}")
        raise
      end
    end
  end
end
