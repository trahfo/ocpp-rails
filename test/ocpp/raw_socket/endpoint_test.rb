require "test_helper"
require "socket"
require "websocket/driver"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    module RawSocket
      # End-to-end coverage of the Rack endpoint. The rejection paths are pure;
      # the acceptance path drives a real socket pair through the full upgrade →
      # auth → 101 → inbound-frame → OCPP-handler loop, proving a bare OCPP-J
      # client (what a real wallbox is) is served without any ActionCable
      # subscription handshake.
      #
      # Non-transactional: a reader thread on its own DB connection must see the
      # committed charge point, so this test commits and cleans up by hand.
      class EndpointTest < ActiveSupport::TestCase
        include OcppTestHelper

        self.use_transactional_tests = false

        # Encodes client->server frames for the acceptance test: WebSocket::Driver
        # .client writes bytes here instead of to a socket.
        class FrameCapture
          attr_reader :url

          def initialize(url)
            @url = url
            @buffer = +"".b
          end

          def write(data)
            @buffer << data
          end

          def read
            @buffer.dup
          end

          def clear
            @buffer = +"".b
          end
        end

        setup do
          Registry.clear!
          @ios = []
          @charge_point = nil
        end

        teardown do
          @ios.each { |io| io.close rescue nil }
          Registry.clear!
          destroy_charge_point(@charge_point)
        end

        test "a non-WebSocket request is told to upgrade" do
          status, headers, = Endpoint.new.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/CP-1")

          assert_equal 426, status
          assert_equal "websocket", headers["upgrade"]
        end

        test "an unauthorized upgrade is refused without hijacking the socket" do
          hijacked = false
          env = upgrade_env(identifier: "CP-UNKNOWN", password: "whatever")
          env["rack.hijack"] = -> { hijacked = true }

          status, headers, = Endpoint.new.call(env)

          assert_equal 401, status
          assert_match(/Basic/, headers["www-authenticate"])
          assert_not hijacked, "must authenticate from the env before taking the socket"
        end

        test "a real bare OCPP-J client connects, boots, and drives a session status" do
          @charge_point = create_charge_point(
            identifier: "CP-E2E-1", auth_password: "station-secret", connected: false, last_heartbeat_at: nil
          )
          server_io, client_io = socket_pair

          # Build the client first so its real Sec-WebSocket-Key drives the env —
          # otherwise the server's Sec-WebSocket-Accept wouldn't match and the
          # client would reject the 101. (Under Puma the browser/station and the
          # env carry the same key naturally; here we mimic that.)
          client, ws_key = build_client("CP-E2E-1")

          env = upgrade_env(identifier: "CP-E2E-1", password: "station-secret", ws_key: ws_key)
          env["rack.hijack"] = -> { env["rack.hijack_io"] = server_io }
          status, = Endpoint.new.call(env)
          assert_equal(-1, status, "the endpoint full-hijacks the connection")

          handshake = read_handshake(client_io)
          assert_match %r{\AHTTP/1\.1 101}, handshake, "expected a WebSocket upgrade response"
          assert_match(/sec-websocket-protocol: ocpp1\.6/i, handshake, "must negotiate the ocpp1.6 subprotocol")
          assert @charge_point.reload.connected?, "station shows connected after the upgrade"

          client.parse(handshake)
          assert_equal :open, client.state, "client accepted the server handshake"

          send_frame(client, client_io,
            [ 2, "m1", "StatusNotification",
              { "connectorId" => 1, "status" => "Available", "errorCode" => "NoError",
                "timestamp" => Time.current.utc.iso8601 } ])

          assert wait_until(5) { @charge_point.reload.connector_status(1) == "Available" },
            "the inbound StatusNotification was handled by the shared OCPP core"

          client_io.close
          assert wait_until(5) { !@charge_point.reload.connected? },
            "closing the socket flips the station to disconnected"
        end

        private

        def socket_pair
          server_io, client_io = UNIXSocket.pair
          @ios.push(server_io, client_io)
          [ server_io, client_io ]
        end

        def upgrade_env(identifier:, password:, protocol: "ocpp1.6", ws_key: SecureRandom.base64(16))
          env = {
            "REQUEST_METHOD" => "GET",
            "PATH_INFO" => "/#{identifier}",
            "HTTP_HOST" => "localhost",
            "HTTP_CONNECTION" => "Upgrade",
            "HTTP_UPGRADE" => "websocket",
            "HTTP_SEC_WEBSOCKET_VERSION" => "13",
            "HTTP_SEC_WEBSOCKET_KEY" => ws_key
          }
          env["HTTP_SEC_WEBSOCKET_PROTOCOL"] = protocol if protocol
          if password
            env["HTTP_AUTHORIZATION"] = "Basic " + Base64.strict_encode64("#{identifier}:#{password}")
          end
          env
        end

        # A WebSocket::Driver.client and the Sec-WebSocket-Key it generated (read
        # back from the upgrade request it wrote), so the server env can carry the
        # matching key. The client's own HTTP request is discarded — the env, not
        # the wire, drives the server handshake here.
        def build_client(identifier)
          capture = FrameCapture.new("ws://localhost/#{identifier}")
          client = WebSocket::Driver.client(capture, protocols: [ "ocpp1.6" ])
          client.start
          ws_key = capture.read[/sec-websocket-key:\s*(\S+)/i, 1]
          capture.clear
          @client_capture = capture
          [ client, ws_key ]
        end

        # Read the 101 response (headers terminate with a blank line).
        def read_handshake(io)
          buffer = +"".b
          deadline = monotonic + 5
          buffer << io.readpartial(4096) until buffer.include?("\r\n\r\n") || monotonic > deadline
          buffer
        end

        def send_frame(client, io, ocpp_array)
          @client_capture.clear
          client.text(ocpp_array.to_json)
          io.write(@client_capture.read)
        end

        def wait_until(seconds)
          deadline = monotonic + seconds
          until yield
            return false if monotonic > deadline

            sleep 0.05
          end
          true
        end

        def monotonic
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        def destroy_charge_point(charge_point)
          return unless charge_point

          id = charge_point.id
          MeterValue.where(charge_point_id: id).delete_all
          ChargingSession.where(charge_point_id: id).delete_all
          ConnectorStatus.where(charge_point_id: id).delete_all
          Message.where(charge_point_id: id).delete_all
          StateChange.where(charge_point_id: id).delete_all
          ChargePoint.where(id: id).delete_all
        end
      end
    end
  end
end
