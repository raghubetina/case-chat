source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Perimeter rate limiting must load before Rodauth so account endpoints pass
# through Rack::Attack before the authentication middleware handles them.
gem "rack-attack"

# Authentication and authorization
gem "rodauth-rails", "~> 2.2.1"
gem "rodauth", "~> 2.45.0", require: false
gem "bcrypt", "~> 3.1.22", require: false
gem "rodauth-i18n", "~> 0.11.0", require: false
gem "sequel-activerecord_connection", "~> 2.0.1", require: false
gem "pundit", "~> 2.5.2"

# First-party AI clients stay behind app-owned provider adapters.
gem "openai", "~> 0.78.0"
gem "anthropic", "~> 1.62.0"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Error tracking, dormant until ROLLBAR_ACCESS_TOKEN exists.
gem "rollbar"

# APM, dormant until SKYLIGHT_AUTHENTICATION exists; production-only.
gem "skylight"

# Catch unsafe DDL before it locks a production table; the
# post-handoff Agent writes migrations against live data.
gem "strong_migrations"

# Paginate every collection (ceiling guardrail: Relations, never Arrays).
gem "pagy"

group :production do
  # Hard request deadline so a wedged request cannot hold a Puma thread forever.
  gem "rack-timeout", require: "rack/timeout/base"

  # Active Storage documents live outside ephemeral web and worker filesystems.
  gem "cloudinary", "~> 2.4.5"
end

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

group :development, :test do
  # Loads .env locally so optional keys (see .env.example) are easy to flip on.
  gem "dotenv-rails"

  # erb_lint's HardCodedString linter catches copy that never reaches t(),
  # keeping generated ERB copy in locale files.
  gem "erb_lint", require: false

  # Schema lints in CI: missing FK indexes, extraneous indexes, null-constraint drift.
  gem "active_record_doctor"

  # Blocks real HTTP in tests, so the suite never depends on an external service.
  gem "webmock", require: false

  # StandardRB is the linter of record; plugins ride .standard.yml.
  gem "standard", require: false
  gem "standard-rails", require: false

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false
end

group :development do
  # Procfile.dev runner. Pin it so bin/dev never mutates the global gemset.
  gem "foreman", "0.90.0"

  # Flags N+1s while clicking around in dev (tests assert query counts instead).
  gem "bullet"

  # Schema annotations atop models on every migration (agent legibility).
  gem "annotaterb"

  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Every system-test page visit gets an axe-core WCAG audit.
  gem "capybara_accessibility_audit"

  # Assert flat query counts in tests (ceiling guardrail).
  gem "n_plus_one_control"

  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
