require "rails/generators"

module Ocpp
  module Rails
    module Generators
      class InstallGenerator < ::Rails::Generators::Base
        source_root File.expand_path("templates", __dir__)

        desc "Installs Ocpp::Rails into your application"

        # The engine's own db/migrate is the schema this gem's models expect,
        # so the install copies those rather than a second, hand-maintained
        # set of templates. The templates had drifted: they never created
        # ocpp_state_changes or ocpp_authorizations (both written by the gem,
        # from the connection/heartbeat state log and from every Authorize and
        # StartTransaction), they declared metadata as jsonb where the engine
        # uses json -- making a generator-installed app Postgres-only for no
        # reason -- and they predated transaction_id becoming an integer, the
        # meter-value anomaly flags and timestamp provenance, the charge
        # point's auth_password_digest, and the active-session guard. An app
        # installed from them got a database the gem then logs errors against
        # at runtime, one per message, with state changes and authorizations
        # silently never stored.
        def copy_migrations
          rake "ocpp_rails:install:migrations"
        end

        def mount_engine
          route "mount Ocpp::Rails::Engine => '/ocpp'"
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
