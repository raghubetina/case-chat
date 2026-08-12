require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CaseChat
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Exceptions render through the router: branded 404/422/500 in the app layout.
    config.exceptions_app = routes

    # Deliberate fixtures only; scaffolds do not scatter per-model stubs,
    # per-resource helpers, or asset files.
    config.generators do |g|
      g.test_framework :test_unit, fixture: false
      g.helper false
      g.assets false
    end

    # Attachment processors belong to the schema-conditional upload layer.
    # Keep Rails' Active Storage substrate inert until that layer selects one.
    config.active_storage.variant_processor = :disabled
  end
end
