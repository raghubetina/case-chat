require "sequel/core"

class RodauthMain < Rodauth::Rails::Auth
  configure do
    enable :create_account, :login, :logout, :change_password, :remember, :i18n

    db Sequel.postgres(
      extensions: [:activerecord_connection, :sql_log_normalizer],
      keep_reference: false
    )
    convert_token_id_to_integer? false

    accounts_table :users
    remember_table :user_remember_keys

    rails_controller { RodauthController }
    title_instance_variable :@page_title

    account_password_hash_column :password_hash

    login_param "email"
    require_login_confirmation? false

    password_minimum_length 8
    password_maximum_bytes 72
    password_hash_cost { Rails.env.test? ? BCrypt::Engine::MIN_COST : BCrypt::Engine::DEFAULT_COST }

    after_login do
      remember_login if param_or_nil(remember_param) == remember_remember_param_value
    end
    remember_cookie_options same_site: :lax

    before_create_account do
      full_name = param("full_name").strip
      if full_name.empty?
        throw_error_status(invalid_field_error_status, "full_name", I18n.t("auth.errors.full_name_required"))
      end

      account[:full_name] = full_name
      account[:created_at] = Sequel::CURRENT_TIMESTAMP
      account[:updated_at] = Sequel::CURRENT_TIMESTAMP
    end

    before_logout do
      remove_remember_key(session_value) if session_value
      forget_login
    end

    after_change_password do
      update_account(updated_at: Sequel::CURRENT_TIMESTAMP)
      remove_remember_key
      forget_login
    end

    login_return_to_requested_location? true
    already_logged_in { redirect login_redirect }
    logout_redirect "/"

    i18n_raise_on_missing_translations? { Rails.env.local? }

    auth_class_eval do
      def normalize_login(login)
        login.strip.downcase
      end
    end
  end
end
