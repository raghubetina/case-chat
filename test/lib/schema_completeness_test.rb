require "test_helper"

# Render provisions a database by loading db/schema.rb, not by replaying
# migrations. So anything a migration creates but the schema file omits does not
# exist in production, and nothing says so.
#
# This is not hypothetical: schema.rb was missing all thirteen solid_* tables
# while the migration that creates them was recorded as applied. A fresh
# database built from it had none of them, which would have taken Solid Queue,
# Solid Cache and Solid Cable down on the first boot — and Rack::Attack rides
# Rails.cache, so the first request would have failed too.
class SchemaCompletenessTest < ActiveSupport::TestCase
  SCHEMA = Rails.root.join("db/schema.rb").freeze

  # Cache, Queue and Cable all run in the primary database here rather than in
  # the separate ones Rails generates, so all three belong in this schema.
  REQUIRED_TABLES = %w[
    solid_cache_entries
    solid_cable_messages
    solid_queue_jobs
    solid_queue_ready_executions
    solid_queue_scheduled_executions
    solid_queue_claimed_executions
    solid_queue_blocked_executions
    solid_queue_failed_executions
    solid_queue_semaphores
    solid_queue_processes
    solid_queue_pauses
    solid_queue_recurring_tasks
    solid_queue_recurring_executions
  ].freeze

  test "the schema file creates every table a deployed box needs" do
    schema = SCHEMA.read

    REQUIRED_TABLES.each do |table|
      assert_match(/create_table "#{table}"/, schema,
        "db/schema.rb must create #{table}: production loads this file, not the migrations, " \
        "so a table only a migration knows about will not exist there")
    end
  end

  # A migration that has run but left nothing in the schema file is the shape of
  # the bug above, and it is invisible from either file alone.
  test "the schema file is not behind the migrations" do
    latest = Rails.root.glob("db/migrate/*.rb").map { |path| path.basename.to_s[/\A\d+/] }.max
    version = SCHEMA.read[/define\(version: ([\d_]+)\)/, 1].to_s.delete("_")

    assert_operator version, :>=, latest,
      "db/schema.rb is at #{version} but migrations run to #{latest}; " \
      "run bin/rails db:migrate and commit the dumped schema"
  end
end
