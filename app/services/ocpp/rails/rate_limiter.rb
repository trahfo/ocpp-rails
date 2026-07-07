module Ocpp
  module Rails
    # Fixed-window rate limiter keyed by station identifier. The limit is
    # re-read from the block on every call so configuration changes apply
    # immediately; a nil limit disables throttling.
    #
    # State is in-process: in multi-server deployments each node applies
    # the limit independently, so treat the configured value as per node.
    class RateLimiter
      PRUNE_THRESHOLD = 1_000

      def initialize(window: 60, &limit)
        @window = window
        @limit = limit
        @mutex = Mutex.new
        @windows = {}
      end

      # Returns true when the event for this key is within the limit.
      def allow?(key, now: Process.clock_gettime(Process::CLOCK_MONOTONIC))
        limit = @limit.call
        return true if limit.nil?

        @mutex.synchronize do
          prune(now) if @windows.size > PRUNE_THRESHOLD

          started_at, count = @windows[key]
          if started_at.nil? || now - started_at >= @window
            @windows[key] = [ now, 1 ]
            true
          elsif count < limit
            @windows[key][1] += 1
            true
          else
            false
          end
        end
      end

      def reset!
        @mutex.synchronize { @windows.clear }
      end

      private

      # Drop expired windows so one-off keys (e.g. unknown identifiers
      # hammering the endpoint) cannot grow the map unboundedly.
      def prune(now)
        @windows.delete_if { |_key, (started_at, _count)| now - started_at >= @window }
      end
    end
  end
end
