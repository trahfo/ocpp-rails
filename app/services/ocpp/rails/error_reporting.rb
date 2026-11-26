module Ocpp
  module Rails
    # Hands a fault the gem has rescued to the host app's error reporter
    # (`Rails.error`), next to the log line the rescue site already writes, so
    # an error tracker or error mail subscribed there hears of it. An app with
    # no subscriber notices nothing.
    #
    # The context names the station and, where known, the OCPP action and
    # message id -- never the payload, which can hold an id tag.
    module ErrorReporting
      SOURCE = "ocpp.rails"
      MAX_CONTEXT_LENGTH = 100

      # `handled: true` alone would make this a warning; these are faults.
      #
      # Rails skips an exception object it has already reported, so a fault
      # that passes two rescue sites still reaches subscribers once.
      def self.report(error, charge_point: nil, action: nil, message_id: nil)
        # Action and message id come straight off the wire. A malformed frame
        # can put anything there, a payload included, so only short strings pass.
        context = { charge_point: charge_point, action: action, message_id: message_id }
          .select { |_, value| value.is_a?(String) }
          .transform_values { |value| value[0, MAX_CONTEXT_LENGTH] }
        ::Rails.error.report(error, handled: true, severity: :error, source: SOURCE, context: context)
      rescue => reporting_error
        # Called from socket threads and rescue blocks: reporting must never
        # be the thing that takes one down.
        ::Rails.logger&.error("[OCPP] error reporting failed: #{reporting_error.class}: #{reporting_error.message}")
      end
    end
  end
end
