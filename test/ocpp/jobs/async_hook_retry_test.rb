# frozen_string_literal: true

require "test_helper"
require_relative "../../support/ocpp_test_helper"

module Ocpp
  module Rails
    class AsyncHookRetryTest < ActiveJob::TestCase
      include OcppTestHelper

      class FailingHook
        def async?
          true
        end

        def call(_record)
          raise "hook failure"
        end
      end

      setup do
        @charge_point = create_charge_point
      end

      test "AsyncHookJob schedules a retry when the hook fails" do
        state_change = StateChange.create!(
          charge_point: @charge_point,
          change_type: "connection",
          old_value: "false",
          new_value: "true"
        )

        assert_enqueued_with(job: AsyncHookJob) do
          AsyncHookJob.perform_now(state_change.id, FailingHook.name)
        end
      end

      test "AuthorizationAsyncHookJob schedules a retry when the hook fails" do
        authorization = Authorization.create!(
          charge_point_id: @charge_point.id,
          id_tag: "RFID1234",
          status: "Accepted"
        )

        assert_enqueued_with(job: AuthorizationAsyncHookJob) do
          AuthorizationAsyncHookJob.perform_now(authorization.id, FailingHook.name)
        end
      end
    end
  end
end
