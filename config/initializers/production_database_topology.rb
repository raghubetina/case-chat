require "uri"

module ProductionDatabaseTopology
  URL_KEYS = %w[
    DATABASE_URL
    CACHE_DATABASE_URL
    QUEUE_DATABASE_URL
    CABLE_DATABASE_URL
  ].freeze

  module_function

  def validate!(environment)
    targets = URL_KEYS.to_h do |key|
      value = environment.fetch(key)
      raise KeyError, "#{key} must not be blank" if value.strip.empty?

      [key, database_target(key, value)]
    end

    duplicate_targets = targets.group_by { |_key, target| target }.select { |_target, entries| entries.many? }
    if duplicate_targets.any?
      raise ArgumentError, "production database URLs must point to four distinct logical databases"
    end

    true
  end

  def database_target(key, value)
    uri = URI.parse(value)
    unless %w[postgres postgresql].include?(uri.scheme) && uri.host.present? && uri.path.present? && uri.path != "/"
      raise ArgumentError, "#{key} must be a PostgreSQL URL with a database name"
    end

    [uri.host.downcase, uri.port || 5432, URI.decode_www_form_component(uri.path.delete_prefix("/"))]
  rescue URI::InvalidURIError
    raise ArgumentError, "#{key} must be a valid PostgreSQL URL"
  end
end

if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
  ProductionDatabaseTopology.validate!(ENV)
end
