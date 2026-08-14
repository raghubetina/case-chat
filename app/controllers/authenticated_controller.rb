class AuthenticatedController < ApplicationController
  before_action :authenticate
  after_action :verify_pundit_authorization

  private

  def verify_pundit_authorization
    if action_name == "index"
      verify_policy_scoped
    else
      verify_authorized
    end
  end
end
