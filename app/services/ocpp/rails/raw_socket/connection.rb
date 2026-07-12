module Ocpp
  module Rails
    module RawSocket
      # One live raw OCPP-J station connection. It wires a websocket driver to the
      # same transport-agnostic core the ActionCable channel uses, so the wire
      # format changes but nothing downstream does:
      #
      #   inbound  station frame ──▶ MessageHandler (parse, route, hooks, audit)
      #   outbound MessageHandler / remote-control jobs ──▶ ChargePointChannel
      #            .broadcast_to(cp, {message:}) ──▶ ActionCable pub/sub ──▶ this
      #            Connection's subscription ──▶ driver.text down the socket
      #
      # Reusing the existing broadcast as the outbound bus means the 10 producer
      # sites (MessageHandler#send_callresult/#send_callerror and every remote
      # command job) are unchanged, and cross-process routing (a job running on a
      # different Puma worker than the socket) comes for free from the pub/sub
      # adapter (async in dev, solid_cable/redis in production).
      #
      # `driver` is any websocket driver (WebSocket::Driver.rack in production, a
      # stub in tests) responding to #on, #text, #ping, #close and, once started,
      # relaying frames via its :message event. This object is transport-only; it
      # never parses OCPP (Protocol/MessageHandler do).
      class Connection
        attr_reader :charge_point

        def initialize(charge_point:, driver:, io: nil, logger: ::Rails.logger, pubsub: nil)
          @charge_point = charge_point
          @driver = driver
          @io = io
          @logger = logger
          @pubsub = pubsub
          @write_mutex = Mutex.new
          @closed = false
        end

        # Wire driver callbacks, displace any prior socket for this station, mark
        # it connected, and start relaying server->station frames. The caller
        # (endpoint) still owns writing the 101 (driver.start) and the read loop.
        def open
          @driver.on(:message) { |event| handle_inbound(event.data) }
          @driver.on(:close)   { close }
          @driver.on(:error)   { |event| log_error("driver error", event) }

          displace_previous
          ::Rails.application.executor.wrap { mark_connected }
          subscribe_outbound
          self
        end

        # Feed one inbound OCPP-J frame (a JSON string) to the shared handler,
        # dropping it if the station is over its per-minute message budget — the
        # same guard, in the same place, as ChargePointChannel#receive.
        def handle_inbound(text)
          return if @closed

          unless Ocpp::Rails.message_rate_limiter.allow?(@charge_point.identifier)
            @logger.warn("[OCPP][security] #{ident}: message rate limit exceeded, dropping message")
            return
          end

          ::Rails.application.executor.wrap do
            MessageHandler.new(@charge_point, text).process
          end
        rescue => e
          log_error("error handling inbound message", e)
        end

        # Relay a frame published on this station's ActionCable broadcasting down
        # the socket. `encoded` is what the pub/sub adapter carries: the JSON
        # dump of {message: "<ocpp-json>"} that broadcast_to produced.
        def relay(encoded)
          return if @closed

          frame = JSON.parse(encoded)["message"]
          write(frame) if frame
        rescue => e
          log_error("error relaying outbound frame", e)
        end

        def write(frame)
          @write_mutex.synchronize { @driver.text(frame) }
        end

        def ping
          @write_mutex.synchronize { @driver.ping }
        rescue => e
          log_error("ping failed", e)
        end

        # Idempotent teardown. Safe to call from the driver's :close event, the
        # endpoint reader thread's ensure, or a displacing reconnect.
        def close
          return if @closed

          @closed = true
          unsubscribe_outbound
          Registry.remove(@charge_point.identifier, self)
          ::Rails.application.executor.wrap { mark_disconnected }
          close_io
          @driver.close
        rescue => e
          log_error("error during teardown", e)
        end

        def closed?
          @closed
        end

        private

        def displace_previous
          previous = Registry.register(@charge_point.identifier, self)
          return if previous.nil? || previous.equal?(self)

          @logger.info("[OCPP][raw] #{ident}: superseding previous connection")
          previous.close
        end

        def subscribe_outbound
          @broadcasting = ChargePointChannel.broadcasting_for(@charge_point)
          @relay = ->(encoded) { relay(encoded) }
          pubsub.subscribe(@broadcasting, @relay)
        end

        def unsubscribe_outbound
          pubsub.unsubscribe(@broadcasting, @relay) if @broadcasting && @relay
        rescue => e
          log_error("unsubscribe failed", e)
        end

        def pubsub
          @pubsub ||= ActionCable.server.pubsub
        end

        def mark_connected
          was = @charge_point.connected
          @charge_point.update(connected: true, last_heartbeat_at: Time.current)
          log_connection_change(was, true)
          @logger.info("[OCPP][raw] #{ident}: connected")
        end

        def mark_disconnected
          was = @charge_point.connected
          @charge_point.disconnect!
          log_connection_change(was, false)
          @logger.info("[OCPP][raw] #{ident}: disconnected")
        end

        def log_connection_change(old_connected, new_connected)
          return if old_connected == new_connected

          StateChange.create!(
            charge_point: @charge_point,
            change_type: "connection",
            connector_id: nil,
            old_value: old_connected.to_s,
            new_value: new_connected.to_s,
            metadata: { source: "raw_socket" }
          )
        rescue => e
          log_error("failed to log state change", e)
        end

        def close_io
          @io.close if @io && !@io.closed?
        rescue => e
          log_error("io close failed", e)
        end

        def ident
          "ChargePoint #{@charge_point.identifier}"
        end

        def log_error(context, error)
          message = error.respond_to?(:message) ? error.message : error.to_s
          @logger.error("[OCPP][raw] #{ident}: #{context}: #{message}")
        end
      end
    end
  end
end
