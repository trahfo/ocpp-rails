Rails.application.routes.draw do
  mount Ocpp::Rails::Engine => "/ocpp-rails"
end
