require "test_helper"

class PwaManifestTest < ActionDispatch::IntegrationTest
  test "the manifest serves valid installable JSON" do
    get pwa_manifest_path(format: :json)

    assert_response :success
    manifest = JSON.parse(response.body)
    assert_equal I18n.t("app_name"), manifest["name"]
    assert manifest["icons"].any?, "manifest needs at least one icon"
    assert_equal "/", manifest["start_url"]
    assert_equal "standalone", manifest["display"]
  end

  test "a branded name with JSON- and HTML-special characters stays valid JSON" do
    tricky = %(Bob's "Grand" & <Fancy> App  Co)

    # Render the template directly instead of issuing a request.
    #
    # A translation override cannot be relied on to survive an HTTP round trip
    # here. I18n.config lives in ActiveSupport::IsolatedExecutionState (isolation
    # level :thread), and the i18n reloader may call I18n.reload! at an executor
    # boundary — which discards stored translations and re-reads en.yml. Whether
    # that fires between storing the override and rendering the response depends
    # on test order, so a request-based version of this test passes or fails by
    # luck. Under forked parallel workers it failed on roughly one seed in eight.
    #
    # The behavior under test is the template's escaping, not the route: the
    # first test above already proves the route serves installable JSON. Class-
    # level render runs inline in this thread with no executor wrap, so there is
    # no boundary for the override to be lost across.
    original = I18n.t("app_name")
    I18n.backend.store_translations(:en, app_name: tricky)

    assert_equal tricky, I18n.t("app_name"), "the override must be in effect before rendering"

    body = ApplicationController.render(template: "pwa/manifest", formats: [:json])

    manifest = JSON.parse(body) # raises if the value broke the JSON
    assert_equal tricky, manifest["name"], "the name must round-trip unescaped (no &quot;, no broken quotes)"
  ensure
    I18n.backend.store_translations(:en, app_name: original) if original
  end
end
