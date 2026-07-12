Ocpp::Rails::Engine.routes.draw do
  # OCPP transport(s), selected by `config.transport` (see Ocpp::Rails::Configuration):
  #
  #   :action_cable (default) — OCPP-J wrapped in the ActionCable JSON protocol.
  #     Charge points connect to: ws://your-host/ocpp/cable
  #   :raw — native bare OCPP-J over a plain WebSocket, what real stations speak.
  #     Charge points connect to: ws://your-host/ocpp/<charge-point-identifier>
  #   :both — mount both (migration).
  #
  # /cable is declared first so it keeps winning over the greedy raw mount at "/".
  if Ocpp::Rails.transport_enabled?(:action_cable)
    mount ActionCable.server => "/cable"
  end

  if Ocpp::Rails.transport_enabled?(:raw)
    mount Ocpp::Rails::RawSocket::Endpoint.new => Ocpp::Rails.configuration.raw_socket_path,
      as: :ocpp_raw_socket
  end
end
