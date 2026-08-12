# Readiness must remain callable if application callbacks or browser gating fail.
# standard:disable Rails/ApplicationController
class ReadinessController < ActionController::Base
  def show
    ActiveRecord::Base.connection.select_value("SELECT 1")
    head :ok
  rescue => error
    Rails.logger.error("Readiness check failed: #{error.class}: #{error.message}")
    head :service_unavailable
  end
end
# standard:enable Rails/ApplicationController
