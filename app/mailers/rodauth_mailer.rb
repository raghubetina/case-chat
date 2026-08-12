class RodauthMailer < ApplicationMailer
  default to: -> { @rodauth.email_to }, from: -> { @rodauth.email_from }

  def verify_account(name, account_id, key)
    @rodauth = rodauth(name, account_id) { @verify_account_key_value = key }
    @account = @rodauth.rails_account

    mail subject: @rodauth.email_subject_prefix + @rodauth.verify_account_email_subject
  end

  def reset_password(name, account_id, key)
    @rodauth = rodauth(name, account_id) { @reset_password_key_value = key }
    @account = @rodauth.rails_account

    mail subject: @rodauth.email_subject_prefix + @rodauth.reset_password_email_subject
  end

  def unlock_account(name, account_id, key)
    @rodauth = rodauth(name, account_id) { @unlock_account_key_value = key }
    @account = @rodauth.rails_account

    mail subject: @rodauth.email_subject_prefix + @rodauth.unlock_account_email_subject
  end

  private

  def rodauth(name, account_id, &)
    instance = RodauthApp.rodauth(name).allocate
    instance.account_from_id(account_id)
    instance.instance_eval(&) if block_given?
    instance
  end
end
