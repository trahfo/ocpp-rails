module Ocpp
  module Rails
    class AuthorizationAsyncHookJob < ApplicationJob
      queue_as :ocpp_hooks

      retry_on StandardError, wait: :exponentially_longer, attempts: 3

      def perform(authorization_id, hook_class_name)
        authorization = Ocpp::Rails::Authorization.find_by(id: authorization_id)

        unless authorization
          ::Rails.logger.warn("Authorization #{authorization_id} not found, may have been cleaned up")
          return
        end

        hook_class = hook_class_name.constantize
        hook = hook_class.new
        hook.call(authorization)
      rescue => error
        ::Rails.logger.error("AuthorizationAsyncHook #{hook_class_name} failed for Authorization #{authorization_id}: #{error.message}")
        raise
      end
    end
  end
end
