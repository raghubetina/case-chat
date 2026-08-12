require "test_helper"
require "yaml"

# The blueprint encodes decisions that are invisible until production is under
# load, so each test below names the failure it prevents rather than just
# mirroring the YAML.
class RenderBlueprintTest < ActiveSupport::TestCase
  setup do
    @blueprint = YAML.safe_load_file(Rails.root.join("render.yaml"))
    @services = @blueprint.fetch("services").index_by { |service| service.fetch("name") }
    @web = @services.fetch("case-chat")
    @worker = @services.fetch("case-chat-worker")
    @group = @blueprint.fetch("envVarGroups").first
    @group_vars = @group.fetch("envVars").index_by { |entry| entry.fetch("key") }
  end

  def env_for(service)
    service.fetch("envVars").filter_map { |e| [e["key"], e["value"]] if e.key?("key") }.to_h
  end

  test "jobs do not run inside Puma" do
    # A contact's reply streams for 10-60 seconds. In-Puma Solid Queue would
    # hold that time inside the web process and starve request threads.
    assert_equal "false", env_for(@web).fetch("SOLID_QUEUE_IN_PUMA")
    assert_equal "worker", @worker.fetch("type")
  end

  test "the worker does not boot a rails server" do
    # bin/docker-entrypoint runs db:prepare only for `./bin/rails server`.
    # Migrations must belong to exactly one process, and that is the web one.
    command = @worker.fetch("dockerCommand")

    assert_equal "./bin/jobs", command
    assert Rails.root.join("bin/jobs").executable?, "bin/jobs must exist and be executable"
  end

  test "both services share one environment group" do
    # A SECRET_KEY_BASE that differs between web and worker means signed
    # cookies and Active Storage URLs minted by one are rejected by the other.
    %w[case-chat case-chat-worker].each do |name|
      groups = @services.fetch(name).fetch("envVars").filter_map { |e| e["fromGroup"] }
      assert_includes groups, @group.fetch("name"), "#{name} must inherit the shared group"
    end

    assert @group_vars.fetch("SECRET_KEY_BASE").key?("generateValue")
  end

  test "Action Cable has somewhere to broadcast that is not the database" do
    # Token streaming is many broadcasts per second per thread; Solid Cable
    # polls Postgres, so every subscriber is a recurring query.
    cable = @services.fetch("case-chat-cable")

    assert_equal "keyvalue", cable.fetch("type")
    assert_equal "noeviction", cable.fetch("maxmemoryPolicy"),
      "evicting pub/sub state would drop stream messages silently"
    assert_equal "case-chat-cable", @group_vars.fetch("REDIS_URL").dig("fromService", "name")
  end

  test "the database is managed and wired to both services" do
    database = @blueprint.fetch("databases").first

    assert_equal "case-chat-db", database.fetch("name")
    assert_equal "case-chat-db", @group_vars.fetch("DATABASE_URL").dig("fromDatabase", "name")
  end

  test "provider keys are never committed" do
    %w[ANTHROPIC_API_KEY OPENAI_API_KEY RESEND_API_KEY].each do |key|
      entry = @group_vars.fetch(key)

      assert_equal false, entry.fetch("sync"), "#{key} must be set in the dashboard, not the repo"
      assert_nil entry["value"]
    end
  end

  test "every service and the database sit in one region" do
    # Cross-region hops would tax every query and every broadcast.
    regions = @blueprint.fetch("services").filter_map { |s| s["region"] }
    regions << @blueprint.fetch("databases").first.fetch("region")

    assert_equal 1, regions.uniq.size, "expected one region, got #{regions.uniq.inspect}"
  end
end
