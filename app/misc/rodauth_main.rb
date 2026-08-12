require "sequel/core"

class RodauthMain < Rodauth::Rails::Auth
  configure do
    enable :i18n, :create_account, :verify_account, :login, :logout,
      :remember, :reset_password, :lockout, :disallow_common_passwords

    db Sequel.postgres(extensions: :activerecord_connection, keep_reference: false)
    convert_token_id_to_integer? { User.columns_hash.fetch("id").type == :integer }

    accounts_table :users
    verify_account_table :user_verification_keys
    reset_password_table :user_password_reset_keys
    account_login_failures_table :user_login_failures
    account_lockouts_table :user_lockouts
    remember_table :user_remember_keys

    rails_controller { RodauthController }
    title_instance_variable :@page_title
    account_status_column :status
    login_param "email"
    login_label { User.human_attribute_name(:email) }
    verify_account_set_password? false

    normalize_login { |login| login.to_s.strip.downcase }
    password_minimum_length 6
    password_maximum_bytes 72
    password_hash_cost { Rails.env.test? ? BCrypt::Engine::MIN_COST : BCrypt::Engine::DEFAULT_COST }
    max_invalid_logins 10
    login_return_to_requested_location? true
    remember_deadline_interval days: 365
    remember_period days: 365
    extend_remember_deadline? true
    remember_cookie_options { {same_site: :lax} }
    # The native login hook below calls remember_login directly. Do not expose
    # Rodauth's user-facing /remember endpoint, which would let an ordinary
    # browser opt into the same year-long cookie.
    remember_route nil

    i18n_available_locales [:en]
    i18n_raise_on_missing_translations? { Rails.env.test? }

    before_create_account do
      full_name = param("full_name").to_s.strip
      if full_name.blank?
        throw_error_status(
          invalid_field_error_status,
          "full_name",
          I18n.t("activerecord.errors.models.user.attributes.full_name.blank")
        )
      end

      account[:full_name] = full_name
      account[:created_at] = Time.current
      account[:updated_at] = Time.current
    end

    # WKWebView may discard session cookies when the process exits. Keep the
    # Rails account authoritative while giving only the native shell a durable,
    # revocable credential. Ordinary browser sign-ins remain session scoped.
    after_login do
      remember_login if rails_controller_eval { hotwire_native_app? }
    end

    before_logout do
      # The logout route can have a valid session without having loaded the
      # account row into Rodauth's request-local cache.
      signed_in_account_id = session_value
      # The schema has one remember key per Account, so explicit logout
      # invalidates durable cookies on every client for that Account.
      remove_remember_key(signed_in_account_id)
    end

    create_verify_account_email do
      RodauthMailer.verify_account(self.class.configuration_name, account_id, verify_account_key_value)
    end

    create_reset_password_email do
      RodauthMailer.reset_password(self.class.configuration_name, account_id, reset_password_key_value)
    end

    create_unlock_account_email do
      RodauthMailer.unlock_account(self.class.configuration_name, account_id, unlock_account_key_value)
    end

    send_email do |email|
      db.after_commit { email.deliver_later }
    end

    email_from { Rails.configuration.x.mail_from }
    email_subject_prefix { "[#{I18n.t("app_name")}] " }
    logout_redirect { login_path }
    verify_account_redirect { login_redirect }
    reset_password_redirect { login_path }
  end
end
