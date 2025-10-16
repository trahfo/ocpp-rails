module Ocpp
  module Rails
    class AsyncHookJob < ApplicationJob
      queue_as :ocpp_hooks

      retry_on StandardError, wait: :exponentially_longer, attempts: 3

      def perform(state_change_id, hook_class_name)
        state_change = Ocpp::Rails::StateChange.find_by(id: state_change_id)

        unless state_change
          ::Rails.logger.warn("StateChange #{state_change_id} not found, may have been cleaned up")
          return
        end

        hook_class = hook_class_name.constantize
        hook = hook_class.new
        hook.call(state_change)
      rescue => error
        ::Rails.logger.error("AsyncHook #{hook_class_name} failed for StateChange #{state_change_id}: #{error.message}")
        raise
      end
    end
  end
end
