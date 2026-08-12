require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "responses carry an enforced Content-Security-Policy with a nonce" do
    get "/up"
    csp = response.headers["Content-Security-Policy"]
    assert csp.present?, "expected an enforced CSP header"
    assert_nil response.headers["Content-Security-Policy-Report-Only"], "CSP must be enforced, not report-only"
    assert_includes csp, "default-src 'self'"
    assert_match(/nonce-[A-Za-z0-9+\/=]{16,}/, csp, "the nonce must be non-empty - an empty nonce-'' is silently ignored by browsers")
    assert_includes csp, "frame-ancestors 'none'"
  end

  test "responses deny unused browser capabilities" do
    get "/up"

    policy = response.headers["Permissions-Policy"]
    assert policy.present?
    assert_includes policy, "camera=()"
    assert_includes policy, "geolocation=()"
    assert_includes policy, "microphone=()"
  end
end
