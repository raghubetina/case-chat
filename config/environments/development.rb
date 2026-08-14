require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.after_initialize do
    # Log/console channels only: keep query findings in developer tooling rather
    # than injecting Bullet's alert and footer UI into application pages.
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.rails_logger = true
  end

  # Settings specified here will take precedence over those in config/application.rb.

  # strict_loading raises on any lazy-loaded association in dev/test, so N+1s
  # surface here instead of in production. Deliberate guardrail — fix the query,
  # don't disable it.
  config.active_record.strict_loading_by_default = true

  # A missing translation key raises rather than silently falling back.
  config.i18n.raise_on_missing_translations = true

  # Make code changes take effect immediately without server restart.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable Action Controller caching. By default Action Controller caching is disabled.
  # Run rails dev:cache to toggle Action Controller caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.public_file_server.headers = {"cache-control" => "public, max-age=#{2.days.to_i}"}
  else
    config.action_controller.perform_caching = false
  end

  # Change to :null_store to avoid any caching.
  config.cache_store = :memory_store

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # Cloudinary when a key is present, so uploads exercise the same service
  # production uses; the local disk otherwise, so a fresh clone still runs.
  config.active_storage.service = ENV["CLOUDINARY_URL"].present? ? :cloudinary : :local

  # Don't care if the mailer can't send.
  # Render messages locally; no development email can reach the internet.
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.raise_delivery_errors = true

  # Make template changes take effect immediately.
  config.action_mailer.perform_caching = false

  # Set localhost to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = {host: "localhost", port: 3000}
  config.x.mail_from = "Case Chat <notifications@example.test>"

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Append comments with runtime information tags to SQL queries in logs.
  config.active_record.query_log_tags_enabled = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Highlight code that triggered redirect in logs.
  config.action_dispatch.verbose_redirect_logs = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true
end
