require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # A keyless generated app is intentionally silent. Adding the authentication
  # token opts production into the Skylight Railtie and its middleware.
  if ENV["SKYLIGHT_AUTHENTICATION"].blank?
    ENV["SKYLIGHT_ENABLED"] = "false"
    ENV["SKYLIGHT_LOG_FILE"] = File::NULL
    ENV["SKYLIGHT_ALERT_LOG_FILE"] = File::NULL
    config.skylight.environments = []
  end

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = {"cache-control" => "public, max-age=#{1.year.to_i}"}

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Keep documents durable and available to both web and worker processes.
  config.active_storage.service = :production

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Hard request deadline (rack-timeout); tune via RACK_TIMEOUT_SERVICE_TIMEOUT.
  config.middleware.use Rack::Timeout, service_timeout: Integer(ENV.fetch("RACK_TIMEOUT_SERVICE_TIMEOUT", 15))

  # Log to $stdout with the current request id as a default log tag.
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent the orchestrator's database-backed readiness probes from clogging up the logs.
  config.silence_healthcheck_path = "/ready"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = {database: {writing: :queue}}
  config.solid_queue.preserve_finished_jobs = false
  config.solid_queue.shutdown_timeout = 50.seconds

  # Production console opens in a rollback-everything sandbox unless --no-sandbox (fat-finger insurance).
  config.sandbox_by_default = true

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = {host: "example.com"}

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Foundation does not know an application's public domains. The later domain
  # policy layer owns any Host Authorization or canonical-host behavior.
end
