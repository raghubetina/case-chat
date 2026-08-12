require "test_helper"
require "yaml"

class RenderBlueprintTest < ActiveSupport::TestCase
  setup do
    blueprint = YAML.safe_load_file(Rails.root.join("render.yaml"))
    @service = blueprint.fetch("services").first
    @environment = @service.fetch("envVars").to_h { |entry| [entry.fetch("key"), entry["value"]] }
  end

  test "leaves the instance plan to Render's durable default" do
    # Render defaults an omitted plan to Starter for a new service and preserves
    # the current plan for an existing service: https://render.com/docs/blueprint-spec
    refute @service.key?("plan")
  end

  test "keeps the proven single-process in-Puma Queue profile" do
    assert_equal "0", @environment.fetch("WEB_CONCURRENCY")
    assert_equal "3", @environment.fetch("RAILS_MAX_THREADS")
    assert_equal "8", @environment.fetch("DB_POOL")
    assert_equal "true", @environment.fetch("SOLID_QUEUE_IN_PUMA")
  end
end
