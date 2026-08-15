require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # A few thousand tokens on the cheapest model is a fraction of a cent, and a
  # case that cost something must not report that it cost nothing.
  test "an amount too small to show at two places says so" do
    assert_equal I18n.t("money.under_a_cent"), money(0.0005)
    assert_equal I18n.t("money.under_a_cent"), money(0.004)
  end

  test "a real amount is money" do
    assert_equal "$5.00", money(5.0)
    assert_equal "$0.01", money(0.006)
  end

  # Nothing spent is nothing spent, which is different from too little to show.
  test "zero is zero rather than under a cent" do
    assert_equal "$0.00", money(0)
  end

  test "an unknown amount renders whatever the caller wants in its place" do
    assert_equal "—", money(nil, unknown: "—")
    assert_nil money(nil)
  end
end
