require "test_helper"
require "erb"
require "yaml"

class SolidAdapterTopologyTest < ActiveSupport::TestCase
  test "gives each production Solid adapter its own database" do
    production = yaml_with_erb("config/database.yml").fetch("production")

    assert_equal %w[cable cache primary queue], production.keys.sort
    assert_equal "db/cache_migrate", production.dig("cache", "migrations_paths")
    assert_equal "db/queue_migrate", production.dig("queue", "migrations_paths")
    assert_equal "db/cable_migrate", production.dig("cable", "migrations_paths")
  end

  test "keeps Solid adapter tables out of the primary schema" do
    primary_schema = Rails.root.join("db/schema.rb").read

    refute_match(/solid_(?:cache|queue|cable)_/, primary_schema)
    assert_match(/solid_cache_entries/, Rails.root.join("db/cache_schema.rb").read)
    assert_match(/solid_queue_jobs/, Rails.root.join("db/queue_schema.rb").read)
    assert_match(/solid_cable_messages/, Rails.root.join("db/cable_schema.rb").read)
  end

  test "connects each Solid adapter to its named production database" do
    assert_equal "cache", yaml_with_erb("config/cache.yml").dig("production", "database")
    assert_equal "cable", yaml_with_erb("config/cable.yml").dig("production", "connects_to", "database", "writing")
    assert_includes Rails.root.join("config/environments/production.rb").read,
      "config.solid_queue.connects_to = {database: {writing: :queue}}"
  end

  test "isolates AI streams from ordinary jobs" do
    workers = yaml_with_erb("config/queue.yml").dig("production", "workers")

    assert_equal ["ai"], workers.first.fetch("queues")
    assert_equal 5, workers.first.fetch("threads")
    assert_equal ["mailers", "default"], workers.second.fetch("queues")
    assert_equal 2, workers.second.fetch("threads")
    assert workers.none? { |worker| worker.fetch("queues") == "*" }
  end

  test "drops successful jobs without running a cleanup scheduler" do
    recurring_tasks = yaml_with_erb("config/recurring.yml").fetch("production")
    production_configuration = Rails.root.join("config/environments/production.rb").read

    assert_empty recurring_tasks
    assert_includes production_configuration, "config.solid_queue.preserve_finished_jobs = false"
  end

  test "retries Cable database interruptions with backoff" do
    reconnect_attempts = yaml_with_erb("config/cable.yml").dig("production", "reconnect_attempts")

    assert_equal [0, 1, 2, 5, 10, 30, 60, 120], reconnect_attempts
  end

  private

  def yaml_with_erb(relative_path)
    YAML.safe_load(
      ERB.new(Rails.root.join(relative_path).read).result,
      aliases: true
    )
  end
end
