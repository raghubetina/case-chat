class ApplicationController < ActionController::Base
  include Pagy::Method
  include Pundit::Authorization

  # The web baseline requires modern browser primitives. Hotwire Native is
  # exempt because its supported OS floor predates Rails' modern Safari floor;
  # the native shell supplies navigation while the web remains progressive.
  allow_browser versions: :modern, unless: :hotwire_native_app?

  private

  def current_user
    rodauth.rails_account
  end
  helper_method :current_user

  def authenticate
    rodauth.require_account
  end
end
