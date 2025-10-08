require_relative "lib/ocpp/rails/version"

Gem::Specification.new do |spec|
  spec.name        = "ocpp-rails"
  spec.version     = Ocpp::Rails::VERSION
  spec.authors     = [ "Jakob Sommerhuber" ]
  spec.email       = [ "jakob@sommerhuber.name" ]
  spec.homepage    = "https://github.com/trahfo/ocpp-rails"
  spec.summary     = "Rails engine that provides OCPP 1.6 - 2.2 communication for EV charging stations"
  spec.description = "Use this engine to communicate to your EV Charging stations"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/trahfo/ocpp-rails/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.0.0"
  spec.add_dependency "websocket-driver", "~> 0.7"

  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "factory_bot_rails", "~> 6.0"
  spec.add_development_dependency "faker", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
