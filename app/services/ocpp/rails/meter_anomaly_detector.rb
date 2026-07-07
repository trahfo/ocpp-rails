module Ocpp
  module Rails
    # Checks Energy.Active.Import.Register readings against the session's
    # series: the register must never decrease (rollover, meter swap) and
    # must not jump implausibly between samples. Anomalous readings are
    # flagged for review instead of silently entering energy accounting.
    module MeterAnomalyDetector
      ENERGY_MEASURAND = "Energy.Active.Import.Register".freeze

      REGISTER_DECREASE = "register_decrease".freeze
      IMPLAUSIBLE_JUMP = "implausible_jump".freeze

      # Returns a flag reason string, or nil when the reading is plausible.
      def self.check(session:, measurand:, value:, unit:)
        return nil unless session && measurand == ENERGY_MEASURAND

        candidate = normalize_to_wh(value, unit)
        return nil unless candidate

        baseline = baseline_wh(session)
        return nil unless baseline

        max_jump = Ocpp::Rails.configuration.implausible_energy_jump_wh
        if candidate < baseline
          REGISTER_DECREASE
        elsif max_jump && candidate - baseline > max_jump
          IMPLAUSIBLE_JUMP
        end
      end

      def self.normalize_to_wh(value, unit)
        return nil if value.nil?

        wh = BigDecimal(value.to_s)
        unit == "kWh" ? wh * 1000 : wh
      rescue ArgumentError
        nil
      end

      # Highest trustworthy register reading seen so far: meterStart plus all
      # previously accepted (unflagged) energy samples, normalised to Wh.
      def self.baseline_wh(session)
        previous = session.meter_values.energy.where(flagged: false).maximum(
          Arel.sql("CASE WHEN unit = 'kWh' THEN value * 1000 ELSE value END")
        )
        [ previous, session.start_meter_value ].compact.max
      end
    end
  end
end
