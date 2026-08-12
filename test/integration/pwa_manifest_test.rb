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

    # Swap in a throwaway backend rather than writing into the global store,
    # and force it to load the locale files BEFORE storing the override.
    #
    # That ordering is the whole fix. I18n::Backend::Simple loads I18n.load_path
    # lazily on first translate, so anything stored beforehand is silently
    # overwritten by en.yml at exactly that moment. The original test wrote into
    # the global backend and then called reload! in its ensure, which left the
    # global backend uninitialized for whatever ran next — so the override could
    # disappear mid-test depending on ordering.
    override = I18n::Backend::Simple.new
    override.send(:init_translations)
    override.store_translations(:en, app_name: tricky)
    original = I18n.backend
    I18n.backend = override

    assert_equal tricky, I18n.t("app_name"), "the override must be in effect before the request"

    get pwa_manifest_path(format: :json)

    assert_response :success
    manifest = JSON.parse(response.body) # raises if the value broke the JSON
    assert_equal tricky, manifest["name"], "the name must round-trip unescaped (no &quot;, no broken quotes)"
  ensure
    I18n.backend = original if original
  end
end
