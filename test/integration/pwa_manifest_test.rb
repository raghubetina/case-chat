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
    I18n.t("app_name") # force the lazy backend to load en.yml before we override
    I18n.backend.store_translations(:en, app_name: tricky)

    get pwa_manifest_path(format: :json)

    assert_response :success
    manifest = JSON.parse(response.body) # raises if the value broke the JSON
    assert_equal tricky, manifest["name"], "the name must round-trip unescaped (no &quot;, no broken quotes)"
  ensure
    I18n.backend.reload!
  end
end
