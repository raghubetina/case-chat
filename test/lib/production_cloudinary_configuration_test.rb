require "test_helper"

class ProductionCloudinaryConfigurationTest < ActiveSupport::TestCase
  CLOUDINARY_URL = "cloudinary://test-api-key:test-api-secret@case-chat-test".freeze

  test "accepts a credentialed Cloudinary URL" do
    assert ProductionCloudinaryConfiguration.validate!("CLOUDINARY_URL" => CLOUDINARY_URL)
  end

  test "rejects a missing or blank Cloudinary URL without exposing another value" do
    missing_error = assert_raises(KeyError) do
      ProductionCloudinaryConfiguration.validate!({})
    end
    blank_error = assert_raises(KeyError) do
      ProductionCloudinaryConfiguration.validate!("CLOUDINARY_URL" => " ")
    end

    assert_includes missing_error.message, "CLOUDINARY_URL"
    assert_includes blank_error.message, "CLOUDINARY_URL"
    refute_includes missing_error.message, CLOUDINARY_URL
    refute_includes blank_error.message, CLOUDINARY_URL
  end

  test "rejects malformed or incomplete Cloudinary URLs without exposing them" do
    invalid_urls = [
      "not a URL",
      "https://test-api-key:test-api-secret@case-chat-test",
      "cloudinary://case-chat-test",
      "cloudinary://test-api-key@case-chat-test",
      "cloudinary://test-api-key:test-api-secret@"
    ]

    invalid_urls.each do |invalid_url|
      error = assert_raises(ArgumentError) do
        ProductionCloudinaryConfiguration.validate!("CLOUDINARY_URL" => invalid_url)
      end

      assert_includes error.message, "CLOUDINARY_URL"
      refute_includes error.message, invalid_url
    end
  end

  test "removes the parser cause from malformed URL errors" do
    malformed_url = "cloudinary://test-api-key:should-never-leak@bad host"

    error = assert_raises(ArgumentError) do
      ProductionCloudinaryConfiguration.validate!("CLOUDINARY_URL" => malformed_url)
    end

    assert_nil error.cause
    refute_includes error.full_message, malformed_url
    refute_includes error.full_message, "should-never-leak"
  end

  test "skips credential validation only for non-production or dummy-secret builds" do
    assert ProductionCloudinaryConfiguration.validate_on_boot!({}, production: false)
    assert ProductionCloudinaryConfiguration.validate_on_boot!(
      {"SECRET_KEY_BASE_DUMMY" => "1"},
      production: true
    )
    assert_raises(KeyError) do
      ProductionCloudinaryConfiguration.validate_on_boot!({}, production: true)
    end
  end
end
