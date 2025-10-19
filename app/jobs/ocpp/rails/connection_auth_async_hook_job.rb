module Ocpp
  module Rails
    class ConnectionAuthAsyncHookJob < ApplicationJob
      queue_as :ocpp_hooks

      retry_on StandardError, wait: :exponentially_longer, attempts: 3

      def perform(username, password, charge_point_id, hook_class_name)
        hook_class = hook_class_name.constantize
        hook = hook_class.new
        hook.call(username, password, charge_point_id)
      rescue => error
        ::Rails.logger.error("ConnectionAuthAsyncHook #{hook_class_name} failed: #{error.message}")
        raise
      end
    end
  end
end
