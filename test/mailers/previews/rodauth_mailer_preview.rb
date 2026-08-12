class RodauthMailerPreview < ActionMailer::Preview
  def verify_account
    RodauthMailer.verify_account(nil, preview_account.id, "preview-verification-key")
  end

  def reset_password
    RodauthMailer.reset_password(nil, preview_account.id, "preview-reset-key")
  end

  def unlock_account
    RodauthMailer.unlock_account(nil, preview_account.id, "preview-unlock-key")
  end

  private

  def preview_account
    User.order(:id).first!
  end
end
