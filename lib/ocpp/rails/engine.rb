module Ocpp
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace Ocpp::Rails
    end
  end
end
