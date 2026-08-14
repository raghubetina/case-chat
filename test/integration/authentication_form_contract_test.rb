require "test_helper"

class AuthenticationFormContractTest < ActionDispatch::IntegrationTest
  PASSWORD = "prototype-password"
  PUBLIC_FORM_PATHS = ["/login", "/create-account"].freeze
  AUTHENTICATED_FORM_PATHS = ["/change-password", "/remember", "/logout"].freeze

  setup do
    @forgery_protection = ActionController::Base.allow_forgery_protection
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery_protection
  end

  test "renders every account form with CSRF protection and Turbo disabled" do
    ActionController::Base.allow_forgery_protection = true
    PUBLIC_FORM_PATHS.each { |path| assert_form_contract(path) }

    user = User.create!(full_name: "Form Tester", email: "forms@example.com", password: PASSWORD)
    get "/login"
    authenticity_token = css_select("input[name='authenticity_token']").first["value"]
    post "/login", params: {
      email: user.email,
      password: PASSWORD,
      authenticity_token: authenticity_token
    }
    assert_redirected_to "/"

    AUTHENTICATED_FORM_PATHS.each { |path| assert_form_contract(path) }
  end

  test "rejects account submissions without a CSRF token" do
    ActionController::Base.allow_forgery_protection = true

    assert_no_difference -> { User.count } do
      assert_raises(ActionController::InvalidAuthenticityToken) do
        post "/create-account", params: {
          full_name: "Missing Token",
          email: "missing-token@example.com",
          password: PASSWORD,
          "password-confirm": PASSWORD
        }
      end
    end

    user = User.create!(full_name: "Login Token", email: "login-token@example.com", password: PASSWORD)
    assert_raises(ActionController::InvalidAuthenticityToken) do
      post "/login", params: {email: user.email, password: PASSWORD}
    end

    get "/change-password"
    assert_redirected_to "/login"
  end

  private

  def assert_form_contract(path)
    get path

    assert_response :success
    assert_select "form.auth-form[action='#{path}'][method='post'][data-turbo='false']", count: 1 do
      assert_select "input[type='hidden'][name='authenticity_token']", count: 1
    end
  end
end
