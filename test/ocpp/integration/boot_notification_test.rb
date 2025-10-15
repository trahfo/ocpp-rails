# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    class BootNotificationTest < ActiveSupport::TestCase
      include OcppTestHelper

      setup do
        @charge_point = create_charge_point(connected: false)
      end

      test "charge point sends valid boot notification and gets accepted" do
        request = build_boot_notification_request(
          charge_point_vendor: "TestVendor",
          charge_point_model: "TestModel v1"
        )

        # Simulate processing the boot notification
        assert_difference "Message.count", 1 do
          message = Message.create!(
            charge_point: @charge_point,
            message_id: SecureRandom.uuid,
            direction: "inbound",
            action: "BootNotification",
            message_type: "CALL",
            payload: request,
            status: "received"
          )

          assert_equal "BootNotification", message.action
          assert_equal request[:chargePointVendor], message.payload["chargePointVendor"]
        end

        # Update charge point with boot notification data
        @charge_point.update!(
          vendor: request[:chargePointVendor],
          model: request[:chargePointModel],
          serial_number: request[:chargePointSerialNumber],
          firmware_version: request[:firmwareVersion],
          iccid: request[:iccid],
          imsi: request[:imsi],
          meter_type: request[:meterType],
          meter_serial_number: request[:meterSerialNumber],
          connected: true
        )

        assert @charge_point.connected
        assert_equal "TestVendor", @charge_point.vendor
        assert_equal "TestModel v1", @charge_point.model
      end

      test "boot notification updates existing charge point" do
        @charge_point.update!(
          vendor: "OldVendor",
          model: "OldModel",
          firmware_version: "0.9.0"
        )

        request = build_boot_notification_request(
          charge_point_vendor: "NewVendor",
          charge_point_model: "NewModel v2"
        )

        @charge_point.update!(
          vendor: request[:chargePointVendor],
          model: request[:chargePointModel],
          firmware_version: request[:firmwareVersion],
          connected: true
        )

        assert_equal "NewVendor", @charge_point.vendor
        assert_equal "NewModel v2", @charge_point.model
        assert_equal "1.0.0", @charge_point.firmware_version
      end

      test "boot notification with minimal required fields" do
        request = {
          chargePointVendor: "MinimalVendor",
          chargePointModel: "MinimalModel"
        }

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "BootNotification",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        assert message.persisted?
        assert_equal "BootNotification", message.action
      end

      test "boot notification response includes required fields" do
        response = build_boot_notification_response(
          status: "Accepted",
          interval: 300
        )

        assert_equal "Accepted", response[:status]
        assert_equal 300, response[:interval]
        assert response[:currentTime].present?
        assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, response[:currentTime])
      end

      test "boot notification can be rejected" do
        response = build_boot_notification_response(
          status: "Rejected",
          interval: 60
        )

        assert_equal "Rejected", response[:status]
        assert_equal 60, response[:interval]
      end

      test "boot notification can be pending" do
        response = build_boot_notification_response(
          status: "Pending",
          interval: 120
        )

        assert_equal "Pending", response[:status]
        assert_equal 120, response[:interval]
      end

      test "boot notification sets charge point to connected" do
        refute @charge_point.connected

        request = build_boot_notification_request

        @charge_point.update!(
          vendor: request[:chargePointVendor],
          model: request[:chargePointModel],
          connected: true,
          last_heartbeat_at: Time.current
        )

        assert @charge_point.connected
        assert @charge_point.last_heartbeat_at.present?
      end

      test "boot notification stores all optional fields" do
        request = build_boot_notification_request

        @charge_point.update!(
          vendor: request[:chargePointVendor],
          model: request[:chargePointModel],
          serial_number: request[:chargePointSerialNumber],
          firmware_version: request[:firmwareVersion],
          iccid: request[:iccid],
          imsi: request[:imsi],
          meter_type: request[:meterType],
          meter_serial_number: request[:meterSerialNumber]
        )

        assert_equal request[:chargePointSerialNumber], @charge_point.serial_number
        assert_equal request[:firmwareVersion], @charge_point.firmware_version
        assert_equal request[:iccid], @charge_point.iccid
        assert_equal request[:imsi], @charge_point.imsi
        assert_equal request[:meterType], @charge_point.meter_type
        assert_equal request[:meterSerialNumber], @charge_point.meter_serial_number
      end

      test "boot notification validates registration status values" do
        valid_statuses = %w[Accepted Pending Rejected]

        valid_statuses.each do |status|
          response = build_boot_notification_response(status: status)
          assert_includes valid_statuses, response[:status]
        end
      end

      test "multiple boot notifications from same charge point" do
        # First boot
        first_request = build_boot_notification_request(
          charge_point_vendor: "Vendor1",
          charge_point_model: "Model1"
        )

        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "BootNotification",
          message_type: "CALL",
          payload: first_request,
          status: "received"
        )

        @charge_point.update!(
          vendor: first_request[:chargePointVendor],
          model: first_request[:chargePointModel],
          connected: true
        )

        # Second boot (after firmware update, for example)
        second_request = build_boot_notification_request(
          charge_point_vendor: "Vendor1",
          charge_point_model: "Model1"
        )
        second_request[:firmwareVersion] = "2.0.0"

        Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "BootNotification",
          message_type: "CALL",
          payload: second_request,
          status: "received"
        )

        @charge_point.update!(firmware_version: second_request[:firmwareVersion])

        assert_equal 2, @charge_point.messages.where(action: "BootNotification").count
        assert_equal "2.0.0", @charge_point.firmware_version
      end

      test "boot notification message is persisted correctly" do
        request = build_boot_notification_request

        message = Message.create!(
          charge_point: @charge_point,
          message_id: SecureRandom.uuid,
          direction: "inbound",
          action: "BootNotification",
          message_type: "CALL",
          payload: request,
          status: "received"
        )

        assert message.persisted?
        assert_equal @charge_point.id, message.charge_point_id
        assert_equal "inbound", message.direction
        assert_equal "CALL", message.message_type
        assert_equal "BootNotification", message.action
        assert_instance_of Hash, message.payload
      end
    end
  end
end
