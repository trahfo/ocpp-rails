module Ocpp
  module Rails
    class ChargePointsController < ApplicationController
      before_action :set_charge_point, only: [:show, :edit, :update, :destroy, :remote_start, :remote_stop]

      def index
        @charge_points = ChargePoint.order(created_at: :desc)
      end

      def show
        @current_session = @charge_point.current_session
        @recent_sessions = @charge_point.charging_sessions.order(created_at: :desc).limit(10)
        @recent_meter_values = @charge_point.meter_values.recent.limit(20)
      end

      def new
        @charge_point = ChargePoint.new
      end

      def create
        @charge_point = ChargePoint.new(charge_point_params)

        if @charge_point.save
          redirect_to @charge_point, notice: "Charge point created successfully."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @charge_point.update(charge_point_params)
          redirect_to @charge_point, notice: "Charge point updated successfully."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @charge_point.destroy
        redirect_to charge_points_url, notice: "Charge point deleted successfully."
      end

      def remote_start
        RemoteStartTransactionJob.perform_later(@charge_point.id, params[:connector_id], params[:id_tag])
        redirect_to @charge_point, notice: "Remote start command sent."
      end

      def remote_stop
        session = @charge_point.current_session
        RemoteStopTransactionJob.perform_later(@charge_point.id, session.id) if session
        redirect_to @charge_point, notice: "Remote stop command sent."
      end

      private

      def set_charge_point
        @charge_point = ChargePoint.find(params[:id])
      end

      def charge_point_params
        params.require(:charge_point).permit(:identifier, :vendor, :model, :serial_number, :ocpp_protocol)
      end
    end
  end
end
