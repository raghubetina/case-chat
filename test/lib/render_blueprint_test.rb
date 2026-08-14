require "test_helper"
require "erb"
require "yaml"

class RenderBlueprintTest < ActiveSupport::TestCase
  setup do
    @blueprint = YAML.safe_load_file(Rails.root.join("render.yaml"))
    @web = @blueprint.fetch("services").find { |service| service.fetch("type") == "web" }
    @worker = @blueprint.fetch("services").find { |service| service.fetch("type") == "worker" }
    @web_environment = keyed_environment(@web)
    @worker_environment = keyed_environment(@worker)
  end

  test "declares paid web and worker services" do
    assert_equal 2, @blueprint.fetch("services").size
    assert_equal "case-chat-codex-web", @web.fetch("name")
    assert_equal "case-chat-codex-worker", @worker.fetch("name")
    assert_equal "standard", @web.fetch("plan")
    assert_equal "standard", @worker.fetch("plan")
    assert_equal "./bin/jobs", @worker.fetch("dockerCommand")
    assert_equal 60, @worker.fetch("maxShutdownDelaySeconds")
  end

  test "lets the web prepare databases and gates the worker on that preparation" do
    assert_equal "./bin/rails db:prepare", @web.fetch("preDeployCommand")
    assert_equal "./bin/wait-for-database-preparation", @worker.fetch("preDeployCommand")
  end

  test "references the dashboard-owned group without managing it" do
    refute @blueprint.key?("envVarGroups")

    [@web, @worker].each do |service|
      group_references = service.fetch("envVars").select { |entry| entry.key?("fromGroup") }
      assert_equal [{"fromGroup" => "case-chat"}], group_references
    end

    %w[DATABASE_URL CACHE_DATABASE_URL QUEUE_DATABASE_URL CABLE_DATABASE_URL].each do |key|
      assert_equal false, @web_environment.fetch(key).fetch("sync")
      assert_equal(
        {"type" => "web", "name" => "case-chat-codex-web", "envVarKey" => key},
        @worker_environment.fetch(key).fetch("fromService")
      )
    end

    assert_equal true, @web_environment.fetch("SECRET_KEY_BASE").fetch("generateValue")
    assert_equal "SECRET_KEY_BASE", @worker_environment.fetch("SECRET_KEY_BASE").dig("fromService", "envVarKey")

    dashboard_managed_keys = %w[
      OPENAI_API_KEY
      ANTHROPIC_API_KEY
      CLOUDINARY_URL
    ]
    blueprint_environment_keys = @web_environment.keys | @worker_environment.keys

    dashboard_managed_keys.each { |key| refute_includes blueprint_environment_keys, key }
  end

  test "keeps runtime configuration on each service" do
    shared_values = {
      "RAILS_ENV" => "production",
      "PORT" => "80",
      "WEB_CONCURRENCY" => "2",
      "RAILS_MAX_THREADS" => "5",
      "DB_POOL" => "5",
      "CACHE_DB_POOL" => "3",
      "AI_JOB_THREADS" => "5",
      "DEFAULT_JOB_THREADS" => "2",
      "RACK_TIMEOUT_SERVICE_TIMEOUT" => "15",
      "RAILS_LOG_LEVEL" => "info",
      "BUNDLE_WITHOUT" => "development:test"
    }

    shared_values.each do |key, value|
      assert_equal value, @web_environment.fetch(key).fetch("value")
      assert_equal value, @worker_environment.fetch(key).fetch("value")
    end

    assert_equal "3", @web_environment.fetch("CABLE_DB_POOL").fetch("value")
    assert_equal "5", @worker_environment.fetch("CABLE_DB_POOL").fetch("value")
  end

  test "configures queue capacity without an in-Puma worker" do
    all_environment_keys = @web_environment.keys | @worker_environment.keys
    ai_threads = @worker_environment.fetch("AI_JOB_THREADS").fetch("value").to_i
    default_threads = @worker_environment.fetch("DEFAULT_JOB_THREADS").fetch("value").to_i
    web_queue_pool = @web_environment.fetch("QUEUE_DB_POOL").fetch("value").to_i
    worker_queue_pool = @worker_environment.fetch("QUEUE_DB_POOL").fetch("value").to_i

    refute_includes all_environment_keys, "SOLID_QUEUE_IN_PUMA"
    refute_includes Rails.root.join("config/puma.rb").read, "plugin :solid_queue"
    assert_equal 5, ai_threads
    assert_equal 2, default_threads
    assert_equal 2, web_queue_pool
    assert_equal 7, worker_queue_pool
    assert_operator worker_queue_pool, :>=, [ai_threads, default_threads].max + 2
  end

  test "pins the public port and keeps auxiliary connection ceilings bounded" do
    ai_threads = @worker_environment.fetch("AI_JOB_THREADS").fetch("value").to_i
    worker_cable_pool = @worker_environment.fetch("CABLE_DB_POOL").fetch("value").to_i

    assert_equal "80", @web_environment.fetch("PORT").fetch("value")
    assert_equal "3", @web_environment.fetch("CABLE_DB_POOL").fetch("value")
    assert_equal 5, worker_cable_pool
    assert_operator worker_cable_pool, :>=, ai_threads
  end

  test "leaves direct connection headroom during rolling deploys" do
    pool_keys = %w[DB_POOL CACHE_DB_POOL QUEUE_DB_POOL CABLE_DB_POOL]
    web_pool_ceiling = pool_keys.sum { |key| environment_value(@web_environment, key).to_i }
    worker_pool_ceiling = pool_keys.sum { |key| environment_value(@worker_environment, key).to_i }
    worker_entries = queue_configuration.fetch("workers").sum { |worker| worker.fetch("processes", 1) }
    recurring_tasks = YAML.safe_load_file(Rails.root.join("config/recurring.yml")).fetch("production")
    queue_only_processes = 2 + (recurring_tasks.empty? ? 0 : 1)

    web_ceiling = @web_environment.fetch("WEB_CONCURRENCY").fetch("value").to_i * web_pool_ceiling
    worker_ceiling = queue_only_processes * environment_value(@worker_environment, "QUEUE_DB_POOL").to_i +
      worker_entries * worker_pool_ceiling
    steady_state_ceiling = web_ceiling + worker_ceiling
    usable_direct_connections = 200 - 10

    assert_equal 80, steady_state_ceiling
    assert_equal 30, usable_direct_connections - (2 * steady_state_ceiling)
  end

  private

  def keyed_environment(service)
    service.fetch("envVars").filter_map do |entry|
      [entry.fetch("key"), entry] if entry.key?("key")
    end.to_h
  end

  def environment_value(service_environment, key)
    service_environment.fetch(key).fetch("value")
  end

  def queue_configuration
    YAML.safe_load(
      ERB.new(Rails.root.join("config/queue.yml").read).result,
      aliases: true
    ).fetch("production")
  end
end
