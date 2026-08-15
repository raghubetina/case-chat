require "test_helper"

class AssetsTest < ActionDispatch::IntegrationTest
  # Any ordinary page in the generic layout will do, but not root: it redirects
  # a signed-out visitor to the sign-in form, and a 302 carries an empty body,
  # so a refute against that body would pass without proving anything.
  test "the layout links only the compiled application stylesheet" do
    get "/privacy"

    assert_response :success
    assert_select "link[rel='stylesheet']", count: 1 do |links|
      href = links.first["href"]
      assert_match %r{/assets/application(?:-[a-z0-9]+)?\.css}, href
      refute_includes href, "application.tailwind"
    end
    refute_includes response.body, 'href="/assets/tailwindcss"'
  end

  test "the generic layout does not invent a canonical URL" do
    get "/privacy", params: {page: 2}

    assert_response :success
    assert_select "link[rel='canonical']", count: 0
  end
end
