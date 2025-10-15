module Ocpp
  module Rails
    class ChargingSessionsController < ApplicationController
      before_action :set_session, only: [:show, :stop]

      def index
        @sessions = ChargingSession.includes(:charge_point).order(created_at: :desc).page(params[:page])
      end

      def show
        @meter_values = @session.meter_values.order(timestamp: :desc).limit(50)
      end

      def stop
        if @session.active?
          RemoteStopTransactionJob.perform_later(@session.charge_point_id, @session.id)
          redirect_to @session, notice: "Stop command sent."
        else
          redirect_to @session, alert: "Session is already stopped."
        end
      end

      private

      def set_session
        @session = ChargingSession.find(params[:id])
      end
    end
  end
end
