# Loaded only by bin/production-smoke. It gives the production queue a durable,
# observable side effect without adding test-only code to the application.
require "active_job"

# This file is required before the Rails application loads, so ApplicationJob
# does not exist yet.
class ProductionSmokeJob < ActiveJob::Base # standard:disable Rails/ApplicationJob
  queue_as :default

  def perform(token)
    Rails.cache.write("production-smoke:job:#{token}", "performed", expires_in: 300)
  end
end
