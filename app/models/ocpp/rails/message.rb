module Ocpp
  module Rails
    class Message < ApplicationRecord
      self.table_name = "ocpp_messages"

      REDACTED = "[redacted]".freeze

      belongs_to :charge_point, class_name: "Ocpp::Rails::ChargePoint"

      validates :message_id, presence: true
      validates :direction, inclusion: { in: %w[inbound outbound] }
      validates :message_type, inclusion: { in: %w[CALL CALLRESULT CALLERROR] }

      scope :inbound, -> { where(direction: "inbound") }
      scope :outbound, -> { where(direction: "outbound") }
      scope :recent, -> { order(created_at: :desc) }

      # Every message this server handles is kept, payload and all, and
      # `authorizationKey` (the station's Security Profile 1 credential)
      # travels through this table in both directions once an app starts
      # setting one: the outbound ChangeConfiguration CALL carries it in the
      # clear as its "value", and a GetConfiguration reply echoes it straight
      # back in `configurationKey`. Redacting before_save, rather than
      # filtering on read, keeps the plaintext out of the database entirely,
      # including in the merged `response` a CALLRESULT writes onto its
      # pending outbound row.
      before_save :redact_secret_configuration_values

      class << self
        # Recursive, and matched on the {"key" => ..., "value" => ...} pair
        # rather than on the key name appearing anywhere: an OCPP-J
        # configuration pair can be a message's whole payload (the outbound
        # ChangeConfiguration) or one entry in a GetConfiguration reply's
        # array of every key the station holds, and a payload is a plain
        # Hash/Array/scalar tree with no single shape to match on. Matching
        # the pair also means a station identifier or a filter value that
        # happens to read "authorizationKey" is never caught by accident.
        def redact_payload(value, keys = Ocpp::Rails.configuration.redacted_configuration_keys)
          return value if keys.blank?

          case value
          when Hash
            # Descend first and redact after, rather than returning early on a
            # match: a pending outbound row is its own {key, value} pair *and*
            # carries the station's reply under "response" once the CALLRESULT
            # lands, so a hash that is itself a secret pair still has to be
            # walked for nested ones.
            descended = value.transform_values { |nested| redact_payload(nested, keys) }
            value_key = secret_value_key(value, keys)
            value_key ? descended.merge(value_key => REDACTED) : descended
          when Array
            value.map { |item| redact_payload(item, keys) }
          else
            value
          end
        end

        private

        # The hash's own "value" key (string or symbol, whichever it uses) when
        # this hash is a configuration pair for one of `keys`, nil otherwise.
        # Key names are compared case-insensitively, as OCPP 1.6 treats
        # configuration keys, so a station spelling it "AuthorizationKey" is
        # redacted too. A pair carrying no value at all is left untouched
        # rather than gaining one.
        def secret_value_key(hash, keys)
          name = hash[:key] || hash["key"]
          return nil unless name.is_a?(String) && keys.any? { |secret| secret.to_s.casecmp?(name) }

          if hash.key?(:value)
            :value
          elsif hash.key?("value")
            "value"
          end
        end
      end

      private

      def redact_secret_configuration_values
        self.payload = self.class.redact_payload(payload)
      end
    end
  end
end
