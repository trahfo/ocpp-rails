module Ocpp
  module Rails
    module RawSocket
      # Process-local map of the live raw connections this process owns, keyed by
      # charge-point identifier. Used to displace a stale socket when a station
      # reconnects (OCPP allows only one live connection per station) and to see
      # how many stations a process holds. NOT used for message delivery — that
      # rides the ActionCable pub/sub bus (see Connection), which already routes
      # across processes.
      #
      # State lives in class ivars, so in development each code reload starts
      # empty (dev drops sockets on reload anyway); in production the process is
      # eager-loaded and never reloaded, so entries persist for the socket's life.
      class Registry
        @mutex = Mutex.new
        @connections = {}

        class << self
          # Record `connection` as the current owner of `identifier`, returning
          # the connection it replaced (if any) so the caller can close it.
          def register(identifier, connection)
            @mutex.synchronize do
              previous = @connections[identifier]
              @connections[identifier] = connection
              previous
            end
          end

          # Drop `connection` only if it is still the current owner (a newer
          # reconnect must not be evicted by an older socket's teardown).
          def remove(identifier, connection)
            @mutex.synchronize do
              @connections.delete(identifier) if @connections[identifier].equal?(connection)
            end
          end

          def [](identifier)
            @mutex.synchronize { @connections[identifier] }
          end

          def size
            @mutex.synchronize { @connections.size }
          end

          def clear!
            @mutex.synchronize { @connections = {} }
          end
        end
      end
    end
  end
end
