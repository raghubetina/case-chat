require "test_helper"

class RodauthMailerTest < ActionMailer::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
    @user = User.create!(full_name: "Jordan Lin", email: "jordan@example.test", status: 2)
  end

  test "verification email is multipart, inline-styled, and safely delivered" do
    user = @user
    message = RodauthMailer.verify_account(nil, user.id, "verification-key")

    assert_equal [user.email], message.to
    assert_equal [Mail::Address.new(Rails.configuration.x.mail_from).address], message.from
    assert_match(/Verify/, message.subject)
    assert_predicate message, :multipart?
    assert_includes message.text_part.decoded, "/verify-account?key="
    assert_includes message.html_part.decoded, "Verify your email address"

    assert_emails 1 do
      message.deliver_now
    end

    delivered = ActionMailer::Base.deliveries.last
    assert_equal [user.email], delivered.to
    assert_match(/style=/, delivered.html_part.decoded)
  end

  test "password reset and unlock emails have their own secure links" do
    user = @user

    reset = RodauthMailer.reset_password(nil, user.id, "reset-key")
    unlock = RodauthMailer.unlock_account(nil, user.id, "unlock-key")

    assert_includes reset.text_part.decoded, "/reset-password?key="
    assert_includes unlock.text_part.decoded, "/unlock-account?key="
    assert_includes reset.html_part.decoded, "Reset your password"
    assert_includes unlock.html_part.decoded, "Unlock your account"
  end

  test "non-production delivery intercepts recipients outside the safelist" do
    user = User.create!(full_name: "Unsafe Recipient", email: "unsafe@outside.test", status: :verified)

    message = RodauthMailer.verify_account(nil, user.id, "verification-key")
    message.deliver_now

    delivered = ActionMailer::Base.deliveries.last
    assert_equal ["developer@example.test"], delivered.to
    assert_equal "unsafe@outside.test", delivered.header["X-Intercepted-To"].to_s
  end
end
