require "websocket/driver"
require "socket"

module Ocpp
  module Rails
    module RawSocket
      # Rack app that terminates native OCPP-J WebSocket connections — what a real
      # charge point speaks (bare `[2,"id","Action",{}]` frames over a plain
      # WebSocket, subprotocol "ocpp1.6", identity in the URL path), with no
      # ActionCable subscription handshake.
      #
      # It authenticates from the Rack env *before* taking the socket, then
      # full-hijacks (Rack `rack.hijack`, supported by Puma), completes the
      # WebSocket upgrade with websocket-driver, and hands the socket to a
      # Connection that bridges to the shared OCPP core. One reader thread per
      # socket feeds inbound bytes to the driver; outbound frames arrive via the
      # Connection's pub/sub subscription.
      #
      # Mount it from the engine when `config.transport` includes :raw.
      class Endpoint
        READ_CHUNK = 16_384

        def call(env)
          return not_websocket unless WebSocket::Driver.websocket?(env)
          return no_hijack unless env["rack.hijack"]

          decision = Handshake.new(env).call
          unless decision.accepted?
            log_reject(decision)
            return unauthorized
          end

          accept(env, decision)
          # Rack full-hijack sentinel: the server must not write a response.
          [ -1, {}, [] ]
        rescue => e
          ::Rails.logger.error("[OCPP][raw] endpoint error: #{e.class}: #{e.message}")
          internal_error
        end

        private

        def accept(env, decision)
          env["rack.hijack"].call
          io = env["rack.hijack_io"]
          enable_tcp_keepalive(io)

          driver = WebSocket::Driver.rack(
            RackSocket.new(env, io),
            protocols: Ocpp::Rails.configuration.websocket_subprotocols,
            max_length: Ocpp::Rails.configuration.raw_socket_max_frame_bytes
          )

          connection = Connection.new(charge_point: decision.charge_point, driver: driver, io: io)
          connection.open
          driver.start # writes the 101 handshake, echoing the negotiated Sec-WebSocket-Protocol
          spawn_reader(io, driver, connection)
        end

        # One blocking reader per socket (Puma's threaded model). websocket-driver
        # parses frames and fires the Connection's :message callback synchronously
        # on this thread; teardown is funnelled through Connection#close so it runs
        # exactly once whether the peer closed, the socket errored, or the driver
        # emitted :close.
        def spawn_reader(io, driver, connection)
          Thread.new do
            Thread.current.name = "ocpp-raw-#{connection.charge_point.identifier}"
            begin
              until connection.closed?
                driver.parse(io.readpartial(READ_CHUNK))
              end
            rescue EOFError, IOError, Errno::ECONNRESET, Errno::EPIPE
              # peer went away / socket closed — normal disconnect
            rescue => e
              ::Rails.logger.error(
                "[OCPP][raw] reader error for #{connection.charge_point.identifier}: #{e.message}"
              )
            ensure
              connection.close
            end
          end
        end

        # Detect a silently-dropped peer (no FIN) so a half-open socket doesn't
        # pin the station "connected" forever; OCPP Heartbeat covers the rest.
        def enable_tcp_keepalive(io)
          io.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true) if io.respond_to?(:setsockopt)
        rescue StandardError
          # non-fatal; some IO objects (e.g. in tests) don't support socket opts
        end

        def not_websocket
          [ 426, { "content-type" => "text/plain", "connection" => "upgrade", "upgrade" => "websocket" },
            [ "Upgrade required" ] ]
        end

        def no_hijack
          [ 501, { "content-type" => "text/plain" }, [ "WebSocket hijacking not supported" ] ]
        end

        # Security-Profile-1 challenge, so a station may (re)send Basic credentials.
        def unauthorized
          [ 401, { "content-type" => "text/plain", "www-authenticate" => %(Basic realm="OCPP") },
            [ "Unauthorized" ] ]
        end

        def internal_error
          [ 500, { "content-type" => "text/plain" }, [ "Internal Server Error" ] ]
        end

        def log_reject(decision)
          ::Rails.logger.warn(
            "[OCPP][security] raw OCPP-J upgrade rejected for #{decision.identifier.inspect}: #{decision.failure}"
          )
        end

        # Adapter presented to WebSocket::Driver.rack: the driver reads the
        # Sec-WebSocket-* handshake headers from #env and writes the 101 response
        # and subsequent frames through #write to the hijacked socket.
        class RackSocket
          attr_reader :env

          def initialize(env, io)
            @env = env
            @io = io
          end

          def write(data)
            @io.write(data)
          end
        end
      end
    end
  end
end
