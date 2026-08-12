# Production error tracking is opt-in by access token. Development, test, and
# keyless production stay dormant and make no external requests.
Rollbar.configure do |config|
  config.access_token = ENV["ROLLBAR_ACCESS_TOKEN"]
  config.environment = ENV["ROLLBAR_ENV"].presence || Rails.env

  # Only an explicitly keyed production app reports. Keyless production boots
  # remain fully dormant instead of relying on notifier internals.
  config.enabled = Rails.env.production? && ENV["ROLLBAR_ACCESS_TOKEN"].present?

  # Expected public misses are quota-consuming noise. Unknown controller
  # actions are deliberately not filtered because they usually indicate bugs.
  config.exception_level_filters.merge!(
    "ActionController::RoutingError" => "ignore",
    "ActiveRecord::RecordNotFound" => "ignore"
  )
end
