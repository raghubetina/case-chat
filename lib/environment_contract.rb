module EnvironmentContract
  # Mirrors dotenv's key and separator grammar without evaluating values.
  # bin/setup calls this before dependencies are guaranteed installed, and a
  # real dotenv parse would also execute command substitutions in values.
  KEY_PATTERN = /[\w.]+/
  DECLARATION_PATTERN = /\A\s*(?:export\s+)?(#{KEY_PATTERN})(?=\s*(?:=|:\s|#|$))/
  COMMENT_PREFIX_PATTERN = /\A\s*#\s?/

  def self.example_keys(path)
    keys_in(path, include_commented: true)
  end

  def self.dotenv_keys(path)
    keys_in(path, include_commented: true)
  end

  def self.active_dotenv_keys(path)
    keys_in(path, include_commented: false)
  end

  def self.drift(example_path:, env_path:)
    example = example_keys(example_path)
    dotenv = dotenv_keys(env_path)

    {
      missing_from_env: example - dotenv,
      undocumented_in_env: dotenv - example
    }
  end

  def self.keys_in(path, include_commented:)
    return [] unless File.exist?(path)

    File.readlines(path, chomp: true).filter_map do |line|
      key = line[DECLARATION_PATTERN, 1]
      next key if key || !include_commented || !line.match?(COMMENT_PREFIX_PATTERN)

      line.sub(COMMENT_PREFIX_PATTERN, "")[DECLARATION_PATTERN, 1]
    end.uniq.sort
  end
  private_class_method :keys_in
end
