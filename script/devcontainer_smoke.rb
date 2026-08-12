#!/usr/bin/env ruby

require "fileutils"
require "tmpdir"
require "yaml"

source = File.expand_path("../.devcontainer", __dir__)

Dir.mktmpdir("compiled-app-") do |temporary_root|
  renamed_app = File.join(temporary_root, "photogram")
  copied_config = File.join(renamed_app, ".devcontainer")
  FileUtils.mkdir_p(renamed_app)
  FileUtils.cp_r(source, copied_config)

  compose_path = File.join(copied_config, "compose.yaml")
  compose = YAML.safe_load_file(compose_path)
  raise "Compose project name must be derived, not hardcoded" if compose.key?("name")

  volumes = compose.dig("services", "rails-app", "volumes") || []
  workspace_mount = volumes.find { |volume| volume.split(":")[1] == "/workspaces/app" }
  raise "rails-app must mount a name-independent /workspaces/app" unless workspace_mount

  mount_source = workspace_mount.split(":").first
  resolved_source = File.expand_path(mount_source, File.dirname(compose_path))
  raise "workspace mount does not resolve to the renamed checkout" unless resolved_source == renamed_app

  devcontainer = File.read(File.join(copied_config, "devcontainer.json"))
  raise "workspaceFolder must match the Compose mount" unless devcontainer.match?(/"workspaceFolder"\s*:\s*"\/workspaces\/app"/)

  copied_files = Dir[File.join(copied_config, "**", "*")].select { |path| File.file?(path) }
  hardcoded_identity = copied_files.find { |path| File.read(path).match?(/foundation[-_]rails/i) }
  raise "generated identity leaked into #{hardcoded_identity}" if hardcoded_identity
end

puts "Dev Container survives a checkout renamed to photogram"
