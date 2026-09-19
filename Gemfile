source "https://rubygems.org"

# Specify your gem's dependencies in ocpp-rails.gemspec.
gemspec

gem "puma"

gem "sqlite3"

# json 3.0 made JSON.parse's options keyword-only, while Active Support's
# JSON.decode still passes them positionally -- on Ruby 4 that is an
# ArgumentError the moment a json column is read, and every ocpp_* table has
# one. Held at 2.x until Rails ships the keyword call.
gem "json", "~> 2.20"

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop-rails-omakase", require: false
