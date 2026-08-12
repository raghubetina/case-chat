require "test_helper"
require "tmpdir"

class FoundationLayerContractTest < ActiveSupport::TestCase
  ATTACHMENT_PROCESSOR_GEMS = %w[image_processing ruby-vips].freeze
  CORE_ROUTE_MAPPINGS = {
    "/" => {controller: "home", action: "index"},
    "/404" => {controller: "errors", action: "not_found"},
    "/422" => {controller: "errors", action: "unprocessable"},
    "/500" => {controller: "errors", action: "internal_error"},
    "/manifest" => {controller: "rails/pwa", action: "manifest"},
    "/privacy" => {controller: "pages", action: "privacy"},
    "/ready" => {controller: "readiness", action: "show"},
    "/terms" => {controller: "pages", action: "terms"},
    "/up" => {controller: "rails/health", action: "show"}
  }.freeze
  CORE_ROUTE_NAMES = %i[
    privacy
    pwa_manifest
    rails_health_check
    readiness_check
    root
    terms
  ].freeze
  DOMAIN_ROUTES = Rails.root.join("config/routes/foundation_domain.rb")
  ROUTES = Rails.root.join("config/routes.rb")
  MAIN_NAVIGATION_PARTIAL = Rails.root.join("app/views/shared/_main_navigation.html.erb")
  SYSTEM_PACKAGE_MANIFESTS = %w[Dockerfile .github/workflows/ci.yml].freeze

  test "keeps attachment processors out of the schema-less Foundation" do
    assert_equal :disabled, Rails.application.config.active_storage.variant_processor

    bundled_gems = Bundler.locked_gems.specs.map(&:name)

    assert_empty ATTACHMENT_PROCESSOR_GEMS & bundled_gems

    libvips_manifests = SYSTEM_PACKAGE_MANIFESTS.select do |path|
      Rails.root.join(path).read.match?(/\blibvips\b/)
    end

    assert_empty libvips_manifests
  end

  test "keeps main navigation in its generated replacement seam" do
    layout = Rails.root.join("app/views/layouts/application.html.erb").read

    assert_path_exists MAIN_NAVIGATION_PARTIAL
    assert_includes layout, '<%= render "shared/main_navigation" %>'
  end

  test "keeps Core routes unchanged beside the Domain seam" do
    CORE_ROUTE_MAPPINGS.each do |path, expected|
      assert_equal expected, Rails.application.routes.recognize_path(path, method: :get)
    end

    assert_empty CORE_ROUTE_NAMES - Rails.application.routes.named_routes.names
  end

  test "draws the generated Domain route fragment" do
    assert_path_exists DOMAIN_ROUTES
    route_lines = ROUTES.readlines(chomp: true).map(&:strip)
    assert_includes route_lines, "draw :foundation_domain"
    assert_includes route_lines, 'root "home#index"'
    assert_operator route_lines.index("draw :foundation_domain"), :>, route_lines.index('root "home#index"')

    Dir.mktmpdir do |directory|
      Pathname(directory).join("foundation_domain.rb").write(<<~RUBY)
        #{DOMAIN_ROUTES.read}
        get "/foundation-domain-contract", to: "home#index"
        get "/foundation-domain-collision", to: "home#index"
      RUBY

      routes = ActionDispatch::Routing::RouteSet.new
      routes.draw_paths = [directory]
      routes.draw do
        get "/foundation-domain-collision", to: "readiness#show"
        draw :foundation_domain
      end

      assert_equal(
        {controller: "home", action: "index"},
        routes.recognize_path("/foundation-domain-contract", method: :get)
      )
      assert_equal(
        {controller: "readiness", action: "show"},
        routes.recognize_path("/foundation-domain-collision", method: :get)
      )
    end
  end
end
