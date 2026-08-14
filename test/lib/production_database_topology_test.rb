require "test_helper"

class ProductionDatabaseTopologyTest < ActiveSupport::TestCase
  DATABASE_URLS = {
    "DATABASE_URL" => "postgresql://case-chat.test/case_chat_production",
    "CACHE_DATABASE_URL" => "postgresql://case-chat.test/case_chat_production_cache",
    "QUEUE_DATABASE_URL" => "postgresql://case-chat.test/case_chat_production_queue",
    "CABLE_DATABASE_URL" => "postgresql://case-chat.test/case_chat_production_cable"
  }.freeze

  test "accepts four distinct logical databases" do
    assert ProductionDatabaseTopology.validate!(DATABASE_URLS)
  end

  test "rejects a missing or blank database URL without exposing another value" do
    missing_error = assert_raises(KeyError) do
      ProductionDatabaseTopology.validate!(DATABASE_URLS.except("CABLE_DATABASE_URL"))
    end
    blank_error = assert_raises(KeyError) do
      ProductionDatabaseTopology.validate!(DATABASE_URLS.merge("QUEUE_DATABASE_URL" => ""))
    end

    assert_includes missing_error.message, "CABLE_DATABASE_URL"
    assert_includes blank_error.message, "QUEUE_DATABASE_URL"
    DATABASE_URLS.each_value do |url|
      refute_includes missing_error.message, url
      refute_includes blank_error.message, url
    end
  end

  test "rejects two URLs that resolve to the same logical database" do
    error = assert_raises(ArgumentError) do
      ProductionDatabaseTopology.validate!(
        DATABASE_URLS.merge("CACHE_DATABASE_URL" => "postgresql://case-chat.test/case_chat_production?sslmode=require")
      )
    end

    assert_includes error.message, "distinct logical databases"
    DATABASE_URLS.each_value { |url| refute_includes error.message, url }
  end
end
