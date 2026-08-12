class ApplicationController < ActionController::Base
  include Pagy::Method
  include ActionPolicy::Controller

  authorize :user, through: :current_user

  # Every domain route requires an account. Rodauth owns the redirect; this is
  # the single place that decides the app is not public.
  rescue_from ActionPolicy::Unauthorized, with: :forbidden

  # The web baseline requires modern browser primitives. Hotwire Native is
  # exempt because its supported OS floor predates Rails' modern Safari floor;
  # the native shell supplies navigation while the web remains progressive.
  allow_browser versions: :modern, unless: :hotwire_native_app?

  private

  def authenticate
    rodauth.require_account
  end

  def current_user
    rodauth.rails_account
  end
  helper_method :current_user

  def forbidden
    render "errors/forbidden", status: :forbidden, layout: "application"
  end
end
