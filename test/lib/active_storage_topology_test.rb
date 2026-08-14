require "test_helper"

class ActiveStorageTopologyTest < ActiveSupport::TestCase
  test "uses authenticated signed Cloudinary storage in production" do
    production_environment = Rails.root.join("config/environments/production.rb").read
    storage = production_storage_configuration

    assert_includes production_environment, "config.active_storage.service = :production"
    refute_includes production_environment, "config.active_storage.service = :local"
    assert_equal "Cloudinary", storage.fetch("service")
    assert_equal true, storage.fetch("secure")
    assert_equal "authenticated", storage.fetch("type")
    assert_equal true, storage.fetch("sign_url")
    assert_equal "case-chat-codex", storage.fetch("folder")
  end

  test "does not duplicate Cloudinary credentials in storage configuration" do
    storage_source = Rails.root.join("config/storage/production.yml").read

    refute_includes storage_source, "api_key"
    refute_includes storage_source, "api_secret"
    refute_includes storage_source, "cloud_name"
    refute_includes storage_source, "CLOUDINARY_URL"
  end

  test "does not expose the default Active Storage routes" do
    active_storage_routes = Rails.application.routes.routes.select do |route|
      route.defaults[:controller].to_s.start_with?("active_storage/")
    end

    assert_equal false, Rails.application.config.active_storage.draw_routes
    assert_empty active_storage_routes
  end

  private

  def production_storage_configuration
    ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/storage/production.yml")).fetch("production")
  end
end
