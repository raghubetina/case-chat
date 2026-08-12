# Development is exempt from CSP entirely (not even report-only): dev tooling
# (web-console, Rails' exception pages, profilers) injects nonceless inline
# assets, and report-only mode still spams the browser console with violation
# warnings. The test environment stays enforced and is load-bearing: the
# headless-Chrome system tests run under the full policy, so nonceless inline
# assets in the template fail CI instead of production. Do not relax test to
# make a test pass.
unless Rails.env.development?
  # Enforced from birth (not report-only): an inert CSP is a false sense of security,
  # and esbuild-emitted assets are nonce-compatible. If a real inline need ever forces
  # a loosening, record which directive and why beside the change.
  #
  # Reading: MDN CSP (developer.mozilla.org/en-US/docs/Web/HTTP/CSP), the Rails Security Guide
  # CSP section, and the OWASP Content-Security-Policy cheat sheet.
  Rails.application.configure do
    config.content_security_policy do |policy|
      policy.default_src :self       # deny by default; only same-origin unless a directive below widens it
      policy.font_src :self, :data   # fonts: same-origin or inline data: URIs
      policy.img_src :self, :data    # images: same-origin or inline data: URIs
      policy.object_src :none        # no <object>/<embed>/plugins (legacy Flash-era attack surface)
      policy.script_src :self        # scripts: same-origin only (plus a per-request nonce, below)
      policy.style_src :self         # styles: same-origin only (plus nonce)
      policy.frame_ancestors :none   # anti-clickjacking: this app may not be embedded in a frame
      policy.base_uri :self          # block injected <base> tags that rewrite relative URLs
      policy.form_action :self       # forms may only submit back to same-origin
    end

    # Random per request, NOT request.session.id (blank until a session exists -> invalid nonce).
    config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
    config.content_security_policy_nonce_directives = %w[script-src style-src]

    # The exceptions app is invoked from ShowExceptions without re-entering the
    # middleware stack. Keep CSP outside it so real 404/422/500 responses retain
    # the same policy and nonce guarantees as successful responses.
    config.middleware.move_before ActionDispatch::ShowExceptions, ActionDispatch::ContentSecurityPolicy::Middleware
  end
end
