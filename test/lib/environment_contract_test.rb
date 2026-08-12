require "test_helper"
require "dotenv"
require "tmpdir"
require Rails.root.join("lib/environment_contract")

class EnvironmentContractTest < ActiveSupport::TestCase
  test "reports documented keys missing from dotenv" do
    Dir.mktmpdir do |directory|
      example = File.join(directory, ".env.example")
      dotenv = File.join(directory, ".env")
      File.write(example, "# DATABASE_URL=\n# RESEND_API_KEY=\n")
      File.write(dotenv, "DATABASE_URL=postgres://example\n")

      assert_equal(
        {missing_from_env: ["RESEND_API_KEY"], undocumented_in_env: []},
        EnvironmentContract.drift(example_path: example, env_path: dotenv)
      )
    end
  end

  test "reports dotenv keys missing from documentation" do
    Dir.mktmpdir do |directory|
      example = File.join(directory, ".env.example")
      dotenv = File.join(directory, ".env")
      File.write(example, "# DATABASE_URL=\n")
      File.write(dotenv, "DATABASE_URL=postgres://example\nINTERNAL_TOKEN=secret\n")

      assert_equal(
        {missing_from_env: [], undocumented_in_env: ["INTERNAL_TOKEN"]},
        EnvironmentContract.drift(example_path: example, env_path: dotenv)
      )
    end
  end

  test "compares key sets without comparing values" do
    Dir.mktmpdir do |directory|
      example = File.join(directory, ".env.example")
      dotenv = File.join(directory, ".env")
      File.write(example, "# DATABASE_URL=example\n")
      File.write(dotenv, "# DATABASE_URL=entirely-different\n")

      assert_equal(
        {missing_from_env: [], undocumented_in_env: []},
        EnvironmentContract.drift(example_path: example, env_path: dotenv)
      )
    end
  end

  test "matches dotenv key and separator grammar" do
    Dir.mktmpdir do |directory|
      dotenv = File.join(directory, ".env")
      contents = <<~DOTENV
        DB_POOL: 8
        lowercase.key=value
        export EXPORTED = value
        EMPTY
      DOTENV
      File.write(dotenv, contents)

      expected_keys = Dotenv::Parser.call(contents, overwrite: true).keys.sort

      assert_equal expected_keys, EnvironmentContract.active_dotenv_keys(dotenv)
    end
  end

  test "reads commented dotenv declarations without treating prose as keys" do
    Dir.mktmpdir do |directory|
      example = File.join(directory, ".env.example")
      File.write(example, <<~DOTENV)
        # Runtime settings:
        # DB_POOL: 8
        # lowercase.key=value
        # export EXPORTED = value
      DOTENV

      assert_equal %w[DB_POOL EXPORTED lowercase.key], EnvironmentContract.example_keys(example)
    end
  end

  test "reports both sides of key-set drift together" do
    Dir.mktmpdir do |directory|
      example = File.join(directory, ".env.example")
      dotenv = File.join(directory, ".env")
      File.write(example, "# DATABASE_URL=\n# DB_POOL: 8\n")
      File.write(dotenv, "DB_POOL: 12\ninternal.flag=true\n")

      assert_equal(
        {missing_from_env: ["DATABASE_URL"], undocumented_in_env: ["internal.flag"]},
        EnvironmentContract.drift(example_path: example, env_path: dotenv)
      )
    end
  end

  test "does not evaluate dotenv values while discovering keys" do
    Dir.mktmpdir do |directory|
      dotenv = File.join(directory, ".env")
      marker = File.join(directory, "must-not-exist")
      File.write(dotenv, "DANGEROUS=$(touch #{marker})\n")

      assert_equal ["DANGEROUS"], EnvironmentContract.active_dotenv_keys(dotenv)
      refute_path_exists marker
    end
  end
end
