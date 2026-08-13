#!/usr/bin/env ruby

require "fileutils"
require "tmpdir"
require "yaml"

# This is a contract smoke, not the Compiler: it exercises the finite identity
# surface the separate Compiler must lower when it instantiates a Foundation.
SOURCE_ROOT = File.expand_path("..", __dir__)
TARGET_MODULE = "Photogram"
TARGET_NAME = "Photogram"
TARGET_SLUG = "photogram"

IDENTITY_REPLACEMENTS = {
  "config/application.rb" => [["CaseChat", TARGET_MODULE]],
  "config/database.yml" => [["case_chat", TARGET_SLUG]],
  "config/locales/en.yml" => [["\"Case Chat\"", TARGET_NAME]],
  "render.yaml" => [["case-chat", TARGET_SLUG]],
  "README.md" => [["# Case Chat", "# #{TARGET_NAME}"]]
}.freeze

def run!(*command, chdir:, env: {})
  return if system(env, *command, chdir: chdir)

  raise "Command failed: #{command.join(" ")}"
end

Dir.mktmpdir("foundation-instantiation-") do |temporary_root|
  target_root = File.join(temporary_root, TARGET_SLUG)
  source_files = IO.popen(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
    chdir: SOURCE_ROOT,
    &:read
  ).split("\0")

  source_files.each do |relative_path|
    source = File.join(SOURCE_ROOT, relative_path)
    next unless File.file?(source)

    target = File.join(target_root, relative_path)
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(source, target, preserve: true)
  end

  IDENTITY_REPLACEMENTS.each do |relative_path, replacements|
    target = File.join(target_root, relative_path)
    content = File.read(target)
    replacements.each do |source, replacement|
      raise "Expected identity #{source.inspect} in #{relative_path}" unless content.include?(source)

      content = content.gsub(source, replacement)
    end
    File.write(target, content)
  end

  application = File.read(File.join(target_root, "config/application.rb"))
  raise "Rails module was not instantiated" unless application.include?("module #{TARGET_MODULE}")

  databases = File.read(File.join(target_root, "config/database.yml"))
  raise "development database was not instantiated" unless databases.include?("database: #{TARGET_SLUG}_development")
  raise "test database was not instantiated" unless databases.include?("database: #{TARGET_SLUG}_test")

  locales = YAML.safe_load_file(File.join(target_root, "config/locales/en.yml"))
  raise "display name was not instantiated" unless locales.dig("en", "app_name") == TARGET_NAME

  blueprint = YAML.safe_load_file(File.join(target_root, "render.yaml"))
  web_service = blueprint.fetch("services").find { |service| service["type"] == "web" }
  raise "Render web service was not instantiated" unless web_service.fetch("name") == TARGET_SLUG

  # Web, worker, Key Value, database, and env group all hang off one stem, so
  # any surviving mention is an identity the Compiler could not lower.
  leftovers = File.read(File.join(target_root, "render.yaml")).scan(/case[-_]chat/i).uniq
  raise "render.yaml still names the source app: #{leftovers.inspect}" if leftovers.any?

  rails = File.join(target_root, "bin/rails")
  # The smoke owns this disposable database. Never let a caller's Rails-level
  # URL redirect db:prepare or the ensure-block db:drop to another database.
  test_env = {
    "BUNDLE_GEMFILE" => File.join(target_root, "Gemfile"),
    "DATABASE_URL" => nil,
    "RAILS_ENV" => "test"
  }
  begin
    run!(rails, "db:prepare", chdir: target_root, env: test_env)
    run!(rails, "runner", <<~RUBY, chdir: target_root, env: test_env)
      abort "wrong Rails module" unless Rails.application.class.module_parent_name == "#{TARGET_MODULE}"
      abort "wrong application name" unless I18n.t("app_name") == "#{TARGET_NAME}"
      expected_database = "#{TARGET_SLUG}_test"
      resolved_database = ActiveRecord::Base.connection_db_config.database
      suffix = resolved_database.delete_prefix(expected_database)
      valid_database = suffix.empty? || suffix.match?(/^_[0-9]+$/)
      abort "wrong resolved test database: " + resolved_database unless valid_database
    RUBY
  ensure
    system(test_env.merge("DISABLE_DATABASE_ENVIRONMENT_CHECK" => "1"), rails, "db:drop", chdir: target_root)
  end
end

puts "Foundation instantiates and boots as #{TARGET_NAME}"
