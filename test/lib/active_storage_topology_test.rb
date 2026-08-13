require "test_helper"

class ActiveStorageTopologyTest < ActiveSupport::TestCase
  STORAGE_ENVIRONMENT = {
    "OBJECT_STORAGE_ACCESS_KEY_ID" => "test-access-key",
    "OBJECT_STORAGE_SECRET_ACCESS_KEY" => "test-secret-key",
    "OBJECT_STORAGE_REGION" => "test-region",
    "OBJECT_STORAGE_BUCKET" => "case-chat-test"
  }.freeze

  test "uses durable S3-compatible storage in production" do
    production_environment = Rails.root.join("config/environments/production.rb").read

    assert_includes production_environment, "config.active_storage.service = :production"
    refute_includes production_environment, "config.active_storage.service = :local"

    with_environment(STORAGE_ENVIRONMENT) do
      storage = production_storage_configuration

      assert_equal "S3", storage.fetch("service")
      assert_equal false, storage.fetch("public")
      assert_equal "test-access-key", storage.fetch("access_key_id")
      assert_equal "test-secret-key", storage.fetch("secret_access_key")
      assert_equal "test-region", storage.fetch("region")
      assert_equal "case-chat-test", storage.fetch("bucket")
      assert_equal false, storage.fetch("force_path_style")
      refute storage.key?("endpoint")
    end
  end

  test "supports an optional S3-compatible endpoint and path-style URLs" do
    with_environment(
      STORAGE_ENVIRONMENT.merge(
        "OBJECT_STORAGE_ENDPOINT" => "https://objects.example.test",
        "OBJECT_STORAGE_FORCE_PATH_STYLE" => "true"
      )
    ) do
      storage = production_storage_configuration

      assert_equal "https://objects.example.test", storage.fetch("endpoint")
      assert_equal true, storage.fetch("force_path_style")
      assert_equal "when_required", storage.fetch("request_checksum_calculation")
      assert_equal "when_required", storage.fetch("response_checksum_validation")
    end
  end

  test "requires the production object-storage identity" do
    required_keys = STORAGE_ENVIRONMENT.keys

    required_keys.each do |missing_key|
      environment = STORAGE_ENVIRONMENT.except(missing_key)

      assert_raises(KeyError, "expected #{missing_key} to be required") do
        with_environment(environment) { production_storage_configuration }
      end
    end
  end

  test "rejects blank production object-storage values" do
    STORAGE_ENVIRONMENT.each_key do |blank_key|
      environment = STORAGE_ENVIRONMENT.merge(blank_key => "")

      assert_raises(KeyError, "expected #{blank_key} to reject a blank value") do
        with_environment(environment) { production_storage_configuration }
      end
    end
  end

  private

  def production_storage_configuration
    ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/storage/production.yml")).fetch("production")
  end

  def with_environment(values)
    keys = STORAGE_ENVIRONMENT.keys + %w[OBJECT_STORAGE_ENDPOINT OBJECT_STORAGE_FORCE_PATH_STYLE]
    previous_values = ENV.to_h.slice(*keys)

    keys.each { |key| ENV.delete(key) }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    keys.each { |key| ENV.delete(key) }
    previous_values.each { |key, value| ENV[key] = value }
  end
end
