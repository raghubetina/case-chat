require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  PASSWORD = "a secure prototype password"

  test "creates an account with canonical identity and an inline password hash" do
    assert_difference -> { User.count }, 1 do
      post "/create-account", params: {
        full_name: "  Ada Lovelace  ",
        email: "  ADA@EXAMPLE.COM  ",
        password: PASSWORD,
        "password-confirm": PASSWORD
      }
    end

    assert_redirected_to "/"

    user = User.find_by!(email: "ada@example.com")
    assert_equal "Ada Lovelace", user.full_name
    assert BCrypt::Password.new(user.password_hash).is_password?(PASSWORD)

    get "/change-password"
    assert_response :success
  end

  test "rejects an account without a name" do
    assert_no_difference -> { User.count } do
      post "/create-account", params: {
        full_name: "  ",
        email: "nameless@example.com",
        password: PASSWORD,
        "password-confirm": PASSWORD
      }
    end

    assert_response :unprocessable_entity
  end

  test "rejects a canonical duplicate email" do
    create_user(email: "duplicate@example.com")

    assert_no_difference -> { User.count } do
      post "/create-account", params: {
        full_name: "Duplicate User",
        email: "  DUPLICATE@EXAMPLE.COM  ",
        password: PASSWORD,
        "password-confirm": PASSWORD
      }
    end

    assert_response :unprocessable_entity
  end

  test "enforces the bcrypt password byte boundary before hashing" do
    too_long_password = ("a" * 71) + "é"
    maximum_password = "é" * 36

    assert_equal 72, too_long_password.length
    assert_equal 73, too_long_password.bytesize
    assert_equal 36, maximum_password.length
    assert_equal 72, maximum_password.bytesize

    assert_no_difference -> { User.count } do
      post "/create-account", params: {
        full_name: "Long Password",
        email: "too-long@example.com",
        password: too_long_password,
        "password-confirm": too_long_password
      }
    end
    assert_response :unprocessable_entity

    assert_difference -> { User.count }, 1 do
      post "/create-account", params: {
        full_name: "Maximum Password",
        email: "maximum@example.com",
        password: maximum_password,
        "password-confirm": maximum_password
      }
    end
    assert_redirected_to "/"
  end

  test "rejects login for an account without a password" do
    user = User.create!(full_name: "No Password", email: "no-password@example.com")

    post "/login", params: {email: user.email, password: PASSWORD}

    assert_response :unauthorized
    get "/change-password"
    assert_redirected_to "/login"
  end

  test "logs in with a canonicalized email and logs out" do
    user = create_user(email: "grace@example.com")

    post "/login", params: {email: "  GRACE@EXAMPLE.COM  ", password: PASSWORD}
    assert_redirected_to "/"
    assert_nil remember_key_for(user)
    assert_predicate cookies["_remember"], :blank?

    post "/logout"
    assert_redirected_to "/"

    get "/change-password"
    assert_redirected_to "/login"
  end

  test "does not switch accounts while a remembered user is signed in" do
    remembered_user = User.create!(
      full_name: "Remembered Identity",
      email: "remembered-identity@example.com",
      password: PASSWORD
    )
    other_user = User.create!(
      full_name: "Other Identity",
      email: "other-identity@example.com",
      password: PASSWORD
    )
    browser = open_session

    browser.post "/login", params: {
      email: remembered_user.email,
      password: PASSWORD,
      remember: "remember"
    }
    assert_equal 302, browser.response.status

    browser.post "/login", params: {
      email: other_user.email,
      password: PASSWORD
    }
    browser.follow_redirect!

    assert_includes browser.response.body, remembered_user.full_name
    refute_includes browser.response.body, other_user.full_name
  end

  test "does not create another account while signed in" do
    signed_in_user = User.create!(
      full_name: "Signed In Identity",
      email: "signed-in-identity@example.com",
      password: PASSWORD
    )
    browser = open_session
    browser.post "/login", params: {email: signed_in_user.email, password: PASSWORD}

    assert_no_difference -> { User.count } do
      browser.post "/create-account", params: {
        full_name: "Unexpected Identity",
        email: "unexpected-identity@example.com",
        password: PASSWORD,
        "password-confirm": PASSWORD
      }
    end
    browser.follow_redirect!

    assert_includes browser.response.body, signed_in_user.full_name
    refute_includes browser.response.body, "Unexpected Identity"
  end

  test "restores only an explicitly remembered login and revokes it on logout" do
    user = create_user(email: "remembered@example.com")
    browser = open_session

    browser.post "/login", params: {
      email: user.email,
      password: PASSWORD,
      remember: "remember"
    }
    assert_equal 302, browser.response.status
    set_cookie = Array(browser.response.headers.fetch("Set-Cookie")).join("\n")
    assert_match(/SameSite=Lax/i, set_cookie)

    remember_cookie = browser.cookies["_remember"]
    assert remember_cookie
    assert remember_key_for(user)

    remembered_browser = open_session
    remembered_browser.cookies["_remember"] = remember_cookie
    remembered_browser.get "/change-password"
    assert_equal 200, remembered_browser.response.status

    remembered_browser.post "/logout"
    assert_equal 302, remembered_browser.response.status
    assert_nil remember_key_for(user)
    assert_predicate remembered_browser.cookies["_remember"], :blank?
  end

  test "does not rearm a browser after forgetting its remembered login" do
    user = create_user(email: "forgotten-browser@example.com")
    browser = remembered_session_for(user)

    browser.post "/remember", params: {remember: "forget"}
    assert_equal 302, browser.response.status
    assert_predicate browser.cookies["_remember"], :blank?
    assert remember_key_for(user)

    travel 2.hours do
      browser.get "/"
    end

    assert_predicate browser.cookies["_remember"], :blank?
    assert remember_key_for(user)
  end

  test "does not rearm remembered login after disabling it" do
    user = create_user(email: "disabled-remember@example.com")
    browser = remembered_session_for(user)

    browser.post "/remember", params: {remember: "disable"}
    assert_equal 302, browser.response.status
    assert_nil remember_key_for(user)

    travel 2.hours do
      browser.get "/"
    end

    assert_nil remember_key_for(user)
    browser.cookies.delete(Rails.application.config.session_options.fetch(:key))
    browser.get "/change-password"
    assert_equal 302, browser.response.status
    assert_equal "/login", URI(browser.response.location).path
    assert_predicate browser.cookies["_remember"], :blank?
  end

  test "changes a password and revokes the remembered login" do
    user = create_user(email: "change@example.com")
    browser = open_session
    new_password = "a different secure password"
    user.update_columns(updated_at: 1.day.ago)
    previous_updated_at = user.reload.updated_at

    browser.post "/login", params: {
      email: user.email,
      password: PASSWORD,
      remember: "remember"
    }
    assert remember_key_for(user)

    browser.post "/change-password", params: {
      password: PASSWORD,
      "new-password": new_password,
      "password-confirm": new_password
    }
    assert_equal 302, browser.response.status
    assert_nil remember_key_for(user)
    assert_predicate browser.cookies["_remember"], :blank?
    assert_operator user.reload.updated_at, :>, previous_updated_at

    travel 2.hours do
      browser.get "/"
    end
    assert_nil remember_key_for(user)
    assert_predicate browser.cookies["_remember"], :blank?

    old_password_browser = open_session
    old_password_browser.post "/login", params: {email: user.email, password: PASSWORD}
    assert_equal 401, old_password_browser.response.status

    new_password_browser = open_session
    new_password_browser.post "/login", params: {email: user.email, password: new_password}
    assert_equal 302, new_password_browser.response.status
  end

  test "rejects a password change with the wrong current password" do
    user = create_user(email: "wrong-current@example.com")
    browser = open_session

    browser.post "/login", params: {email: user.email, password: PASSWORD}
    browser.post "/change-password", params: {
      password: "not the current password",
      "new-password": "a replacement password",
      "password-confirm": "a replacement password"
    }

    assert_equal 401, browser.response.status

    login_browser = open_session
    login_browser.post "/login", params: {email: user.email, password: PASSWORD}
    assert_equal 302, login_browser.response.status
  end

  test "redirects an unauthenticated account page to login" do
    get "/change-password"

    assert_redirected_to "/login"
  end

  test "does not expose deferred account-management endpoints" do
    %w[/reset-password-request /reset-password /verify-account /close-account /change-login].each do |path|
      assert_raises(ActionController::RoutingError, path) { get path }
    end
  end

  private

  def create_user(email:)
    User.create!(full_name: "Test User", email: email, password: PASSWORD)
  end

  def remember_key_for(user)
    User::RememberKey.find_by(id: user.id)
  end

  def remembered_session_for(user)
    open_session.tap do |browser|
      browser.post "/login", params: {
        email: user.email,
        password: PASSWORD,
        remember: "remember"
      }
      assert_equal 302, browser.response.status
      assert browser.cookies["_remember"]
      assert remember_key_for(user)
    end
  end
end
