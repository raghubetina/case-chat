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

# Full account lifecycle on the existing User table. Password hashes stay in
# Rodauth's separate table so ordinary User queries can never expose them.
gem "bcrypt", "~> 3.1"
gem "rodauth-i18n", "~> 0.11"
gem "rodauth-rails", "~> 2.1"
gem "sequel-activerecord_connection", "~> 2.0", require: false

# Transactional mail in production; dormant until RESEND_API_KEY exists.
gem "resend", "~> 1.6"

# premailer turns the shared mailer stylesheet into email-safe inline styles.
gem "premailer-rails"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Action Cable's redis adapter, used in production where a Key Value instance
# is provisioned. Solid Cable remains the fallback; see config/cable.yml.
gem "redis", "~> 5.4"

# Error tracking, dormant until ROLLBAR_ACCESS_TOKEN exists.
gem "rollbar"

# APM, dormant until SKYLIGHT_AUTHENTICATION exists; production-only.
gem "skylight"

# Catch unsafe DDL before it locks a production table; the
# post-handoff Agent writes migrations against live data.
gem "strong_migrations"

# Paginate every collection (ceiling guardrail: Relations, never Arrays).
gem "pagy"

# Relationship-based authorization. Roles here are relational, not a column:
# you author a case or you are enrolled in one.
gem "action_policy", "~> 0.7"

# First-party Anthropic SDK. Chosen over a cross-provider abstraction because
# prompt caching is the dominant cost lever here (every contact reply resends
# the composed briefing plus the whole thread) and cache_control, cache TTL,
# and cache_read_input_tokens are exactly what an abstraction normalizes away.
# Provider swappability lives in app/models/responder.rb instead, which we own.
gem "anthropic", "~> 1.61"

# OpenAI's Responses API, behind the same Responder seam. Kept alongside rather
# than instead of: it has explicit prompt-cache breakpoints on gpt-5.6+, direct
# file input, and the realtime audio models a future voice mode would need.
gem "openai", "~> 0.78"

# Perimeter per-IP rate limiting; counters ride Rails.cache.
gem "rack-attack"

group :production do
  # Hard request deadline so a wedged request cannot hold a Puma thread forever.
  gem "rack-timeout", require: "rack/timeout/base"
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

  # Render messages locally; no development email can reach the internet.
  gem "letter_opener"
end

group :test do
  # Declarations (validations, associations, dependent:) are Rails' behaviour,
  # not ours. One matcher line states the declaration and goes red if it is
  # removed, instead of a hand-rolled test per attribute that mostly re-proves
  # that Active Record works.
  gem "shoulda-matchers"

  # Every system-test page visit gets an axe-core WCAG audit.
  gem "capybara_accessibility_audit"

  # Assert flat query counts in tests (ceiling guardrail).
  gem "n_plus_one_control"

  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
