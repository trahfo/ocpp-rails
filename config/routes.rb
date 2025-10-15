Ocpp::Rails::Engine.routes.draw do
  root to: "dashboard#index"

  resources :charge_points do
    member do
      post :remote_start
      post :remote_stop
    end
  end

  resources :charging_sessions, only: [:index, :show] do
    member do
      post :stop
    end
  end

  # OCPP WebSocket endpoint
  get "/ocpp/:charge_point_id", to: "websocket#connect"

  # ActionCable mount
  mount ActionCable.server => '/cable'
end
