module Ocpp
  module Rails
    # Moves per-connector status from the pre-0.3.0 metadata convention
    # (connector_<n>_status / _error_code / _updated_at keys on
    # ChargePoint#metadata) into the ocpp_connector_statuses table.
    # Idempotent; rows the station has written since the upgrade win over
    # legacy metadata.
    module ConnectorStatusBackfill
      LEGACY_KEY = /\Aconnector_(\d+)_(status|error_code|updated_at)\z/

      def self.run
        Ocpp::Rails::ChargePoint.find_each do |charge_point|
          metadata = charge_point.metadata || {}
          legacy = metadata.select { |key, _| key.to_s.match?(LEGACY_KEY) }
          next if legacy.empty?

          connector_ids(legacy).each do |connector_id|
            status = legacy["connector_#{connector_id}_status"]
            next unless status

            record = charge_point.connector_statuses.find_or_initialize_by(connector_id: connector_id)
            next if record.persisted?

            record.update!(status: status, error_code: legacy["connector_#{connector_id}_error_code"])
          end

          charge_point.update!(metadata: metadata.except(*legacy.keys))
        end
      end

      def self.connector_ids(legacy)
        legacy.keys.filter_map { |key| key.to_s[LEGACY_KEY, 1]&.to_i }.uniq
      end
      private_class_method :connector_ids
    end
  end
end
