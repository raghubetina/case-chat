require "test_helper"

class ErrorPagesTest < ActionDispatch::IntegrationTest
  test "an unknown route renders the branded 404 in the app layout" do
    with_rendered_exceptions { get "/definitely-not-a-real-page" }

    assert_response :not_found
    assert_select "header.navbar", count: 1, text: /#{Regexp.escape(I18n.t("app_name"))}/
    assert_select "h1", I18n.t("errors.not_found.heading")
    assert_security_headers
  end

  test "the error routes render with their status codes" do
    get "/422"
    assert_response :unprocessable_entity

    get "/500"
    assert_response :internal_server_error
  end

  test "the unprocessable error route returns JSON to an API caller" do
    post "/422", as: :json

    assert_response :unprocessable_content
    assert_equal({"error" => I18n.t("errors.unprocessable.heading")}, response.parsed_body)
  end

  test "a JSON request without an Accept header still receives a JSON error" do
    post "/422",
      params: JSON.generate(device: {token: "expired"}),
      headers: {"CONTENT_TYPE" => "application/json"}

    assert_response :unprocessable_content
    assert_equal "application/json", response.media_type
    assert_equal({"error" => I18n.t("errors.unprocessable.heading")}, response.parsed_body)
  end

  test "a real application exception renders the branded 500" do
    with_routing do |routes|
      routes.draw do
        get "/boom", to: ->(_env) { raise "deliberate test exception" }
        match "/500", to: "errors#internal_error", via: :all
        get "/manifest", to: "rails/pwa#manifest", as: :pwa_manifest
        root "home#index"
      end

      with_rendered_exceptions { get "/boom" }

      assert_response :internal_server_error
      assert_select "header.navbar", count: 1, text: /#{Regexp.escape(I18n.t("app_name"))}/
      assert_select "h1", I18n.t("errors.internal_error.heading")
      assert_security_headers
    end
  end

  test "unrelated tests still raise application exceptions" do
    assert_raises(ActionController::RoutingError) do
      get "/definitely-not-a-real-page"
    end
  end

  private

  def assert_security_headers
    assert response.headers["Content-Security-Policy"].present?
    assert response.headers["Permissions-Policy"].present?
  end

  def with_rendered_exceptions
    env_config = Rails.application.env_config
    previous_show_exceptions = env_config["action_dispatch.show_exceptions"]
    previous_show_detailed_exceptions = env_config["action_dispatch.show_detailed_exceptions"]
    env_config["action_dispatch.show_exceptions"] = :all
    env_config["action_dispatch.show_detailed_exceptions"] = false
    yield
  ensure
    env_config["action_dispatch.show_exceptions"] = previous_show_exceptions
    env_config["action_dispatch.show_detailed_exceptions"] = previous_show_detailed_exceptions
  end
end
