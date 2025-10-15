module Ocpp
  module Rails
    class DashboardController < ApplicationController
      def index
        @charge_points = ChargePoint.order(created_at: :desc)
        @active_sessions = ChargingSession.active.includes(:charge_point)
        @recent_sessions = ChargingSession.completed.order(stopped_at: :desc).limit(10)
      end
    end
  end
end
