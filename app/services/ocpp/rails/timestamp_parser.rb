module Ocpp
  module Rails
    # Parses station-provided OCPP timestamps without hiding failures:
    # a value that cannot be parsed falls back to server receive time,
    # but the result is marked so the record can be flagged instead of
    # silently entering the time series as fabricated data.
    module TimestampParser
      SOURCE_STATION = "station".freeze
      SOURCE_SERVER_FALLBACK = "server_fallback".freeze

      Result = Struct.new(:time, :source, :raw, keyword_init: true) do
        def server_fallback?
          source == SOURCE_SERVER_FALLBACK
        end
      end

      def self.parse(raw)
        Result.new(time: Time.parse(raw), source: SOURCE_STATION, raw: raw)
      rescue ArgumentError, TypeError
        ::Rails.logger.warn("[OCPP] Unparseable timestamp #{raw.inspect}; falling back to server time")
        Result.new(time: Time.current, source: SOURCE_SERVER_FALLBACK, raw: raw)
      end
    end
  end
end
