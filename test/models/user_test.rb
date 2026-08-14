require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "canonicalizes identity through the Active Record boundary" do
    user = User.create!(
      full_name: "  Grace Hopper  ",
      email: "  GRACE.HOPPER@EXAMPLE.COM  "
    )

    assert_equal "Grace Hopper", user.reload.full_name
    assert_equal "grace.hopper@example.com", user.email
  end
end
