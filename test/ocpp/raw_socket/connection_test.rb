require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    module RawSocket
      # Connection wires a websocket driver to the shared OCPP core. These tests
      # drive it with a fake driver and a fake pub/sub so both directions are
      # deterministic and independent of real sockets and the cable adapter.
      class ConnectionTest < ActiveSupport::TestCase
        include ActionCable::TestHelper
        include OcppTestHelper

        MessageEvent = Struct.new(:data)

        # Minimal stand-in for a websocket driver: records outbound text frames
        # and lets a test fire the driver's registered event callbacks.
        class FakeDriver
          attr_reader :sent

          def initialize
            @handlers = {}
            @sent = []
            @closed = false
            @pings = 0
          end

          def on(event, &block)
            @handlers[event] = block
          end

          def text(message)
            @sent << message
          end

          def ping(*)
            @pings += 1
          end

          def pings
            @pings
          end

          def close
            @closed = true
          end

          def closed?
            @closed
          end

          def emit(event, data = nil)
            @handlers[event]&.call(data)
          end
        end

        # In-process pub/sub double matching the adapter contract Connection uses.
        class FakePubsub
          def initialize
            @subs = Hash.new { |h, k| h[k] = [] }
          end

          def subscribe(channel, callback, _success = nil)
            @subs[channel] << callback
          end

          def unsubscribe(channel, callback)
            @subs[channel].delete(callback)
          end

          def publish(channel, payload)
            @subs[channel].each { |cb| cb.call(payload) }
          end

          def subscribers(channel)
            @subs[channel]
          end
        end

        setup do
          @charge_point = create_charge_point(identifier: "CP-CONN-1", connected: false, last_heartbeat_at: nil)
          @driver = FakeDriver.new
          @pubsub = FakePubsub.new
          Registry.clear!
        end

        teardown { Registry.clear! }

        def build(charge_point: @charge_point)
          Connection.new(charge_point: charge_point, driver: @driver, io: nil, pubsub: @pubsub)
        end

        test "open marks the station connected, registers it, and subscribes for outbound frames" do
          connection = build.open

          assert @charge_point.reload.connected?
          assert_not_nil @charge_point.last_heartbeat_at
          assert_equal connection, Registry[@charge_point.identifier]
          assert_equal 1, @pubsub.subscribers(ChargePointChannel.broadcasting_for(@charge_point)).size
        end

        test "open logs a connection state change" do
          assert_difference -> { StateChange.where(change_type: "connection", new_value: "true").count }, 1 do
            build.open
          end
        end

        test "an inbound frame is processed by the shared MessageHandler" do
          build.open

          # A StatusNotification is handled entirely inbound (no CALLRESULT body to
          # relay), and lands in the per-connector status store — a clean assertion
          # that the exact same core ran as on the ActionCable path.
          frame = [ 2, "m1", "StatusNotification",
            { "connectorId" => 1, "status" => "Available", "errorCode" => "NoError" } ].to_json
          @driver.emit(:message, MessageEvent.new(frame))

          assert_equal "Available", @charge_point.connector_status(1)
          assert Message.exists?(charge_point: @charge_point, action: "StatusNotification", direction: "inbound")
        end

        test "inbound CALLs answer via the station broadcasting (the outbound bus)" do
          build.open

          frame = [ 2, "boot-1", "BootNotification",
            { "chargePointVendor" => "V", "chargePointModel" => "M" } ].to_json

          assert_broadcasts(ChargePointChannel.broadcasting_for(@charge_point), 1) do
            @driver.emit(:message, MessageEvent.new(frame))
          end
        end

        test "a frame published on the station broadcasting is relayed down the socket" do
          build.open
          broadcasting = ChargePointChannel.broadcasting_for(@charge_point)
          call = [ 2, "srv-1", "RemoteStartTransaction", { "connectorId" => 1, "idTag" => "RFID1" } ].to_json

          # Exactly the payload broadcast_to publishes: {"message":"<ocpp-json>"}.
          @pubsub.publish(broadcasting, { "message" => call }.to_json)

          assert_equal [ call ], @driver.sent
        end

        test "an over-budget station has its inbound frames dropped" do
          build.open
          limit = Ocpp::Rails.configuration.max_messages_per_minute
          limit.times { Ocpp::Rails.message_rate_limiter.allow?(@charge_point.identifier) }

          frame = [ 2, "m2", "StatusNotification",
            { "connectorId" => 1, "status" => "Faulted", "errorCode" => "NoError" } ].to_json
          @driver.emit(:message, MessageEvent.new(frame))

          assert_nil @charge_point.connector_status(1), "rate-limited frame must not be processed"
        end

        test "an outbound frame that cannot be relayed is reported to Rails.error" do
          build.open
          broadcasting = ChargePointChannel.broadcasting_for(@charge_point)

          report = assert_error_reported(JSON::ParserError) do
            @pubsub.publish(broadcasting, "not json")
          end

          assert_equal "ocpp.rails", report.source
          assert_equal @charge_point.identifier, report.context[:charge_point]
        end

        test "a handler error on an inbound frame is reported once" do
          build.open
          # Missing connectorId makes StartTransactionHandler raise.
          frame = [ 2, "m3", "StartTransaction", { "idTag" => "RFID1" } ].to_json

          reports = capture_error_reports(StandardError) do
            @driver.emit(:message, MessageEvent.new(frame))
          end

          assert_equal 1, reports.size
        end

        test "an error that escapes the message handler is reported as the gem's own, with the station" do
          build.open
          # Without the rescue inside the executor, the executor reports this
          # itself as an unhandled "application.active_support" error.
          MessageHandler.define_singleton_method(:new) { |*| raise "handler exploded" }

          reports = capture_error_reports(RuntimeError) do
            @driver.emit(:message, MessageEvent.new([ 2, "m4", "Heartbeat", {} ].to_json))
          end

          assert_equal 1, reports.size
          assert_equal "ocpp.rails", reports.first.source
          assert reports.first.handled?
          assert_equal @charge_point.identifier, reports.first.context[:charge_point]
        ensure
          MessageHandler.singleton_class.send(:remove_method, :new)
        end

        test "a write to a socket that just died is logged, not reported" do
          build.open
          @driver.define_singleton_method(:text) { |*| raise Errno::EPIPE }
          broadcasting = ChargePointChannel.broadcasting_for(@charge_point)

          assert_no_error_reported do
            @pubsub.publish(broadcasting, { "message" => "[3,\"m5\",{}]" }.to_json)
          end
        end

        test "a failed ping on a dying connection is logged, not reported" do
          connection = build.open
          @driver.define_singleton_method(:ping) { |*| raise IOError, "closed stream" }

          assert_no_error_reported { connection.ping }
        end

        test "close marks disconnected, unsubscribes, drops from the registry, and closes the driver" do
          connection = build.open
          broadcasting = ChargePointChannel.broadcasting_for(@charge_point)

          connection.close

          assert connection.closed?
          assert_not @charge_point.reload.connected?
          assert_nil Registry[@charge_point.identifier]
          assert_equal 0, @pubsub.subscribers(broadcasting).size
          assert @driver.closed?
        end

        test "close is idempotent" do
          connection = build.open

          assert_nothing_raised do
            connection.close
            connection.close
          end
        end

        test "a reconnecting station supersedes and closes its previous connection" do
          first = build.open
          second_driver = FakeDriver.new
          second = Connection.new(charge_point: @charge_point, driver: second_driver, io: nil, pubsub: @pubsub).open

          assert first.closed?, "the stale connection must be torn down"
          assert_not second.closed?
          assert_equal second, Registry[@charge_point.identifier]
        end
      end
    end
  end
end
