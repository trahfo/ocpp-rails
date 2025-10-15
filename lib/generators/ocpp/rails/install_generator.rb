require 'rails/generators'
require 'rails/generators/migration'

module Ocpp
  module Rails
    module Generators
      class InstallGenerator < ::Rails::Generators::Base
        include ::Rails::Generators::Migration

        source_root File.expand_path('templates', __dir__)

        desc "Installs Ocpp::Rails into your application"

        def self.next_migration_number(path)
          Time.now.utc.strftime("%Y%m%d%H%M%S")
        end

        def copy_migrations
          migration_template "create_ocpp_charge_points.rb", "db/migrate/create_ocpp_charge_points.rb"
          sleep 1
          migration_template "create_ocpp_charging_sessions.rb", "db/migrate/create_ocpp_charging_sessions.rb"
          sleep 1
          migration_template "create_ocpp_meter_values.rb", "db/migrate/create_ocpp_meter_values.rb"
          sleep 1
          migration_template "create_ocpp_messages.rb", "db/migrate/create_ocpp_messages.rb"
        end

        def mount_engine
          route "mount Ocpp::Rails::Engine => '/ocpp_admin'"
        end

        def create_initializer
          template "ocpp_rails.rb", "config/initializers/ocpp_rails.rb"
        end

        def show_readme
          readme "README" if behavior == :invoke
        end
      end
    end
  end
end
