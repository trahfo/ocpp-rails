Ocpp::Rails::Engine.routes.draw do
  # OCPP WebSocket endpoint via ActionCable
  # Charge points connect to: ws://your-host/ocpp/cable
  mount ActionCable.server => '/cable'
end
