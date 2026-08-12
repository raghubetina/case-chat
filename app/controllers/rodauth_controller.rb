class RodauthController < ApplicationController
  AUTH_RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new(size: 1.megabyte)
  RATE_LIMITED_ACTIONS = %w[
    create_account
    login
    reset_password_request
    unlock_account_request
    verify_account_resend
  ].freeze

  # Leave one request after Rodauth records its tenth failure so its locked-account
  # screen can direct a real person to the email-unlock flow.
  rate_limit to: 11,
    within: 3.minutes,
    by: -> { "#{request.remote_ip}:#{action_name}" },
    with: :authentication_rate_limit_exceeded,
    store: AUTH_RATE_LIMIT_STORE,
    name: "authentication",
    if: -> { request.post? && action_name.in?(RATE_LIMITED_ACTIONS) }

  private

  def authentication_rate_limit_exceeded
    render plain: t("rate_limit.authentication_exceeded"), status: :too_many_requests
  end
end
