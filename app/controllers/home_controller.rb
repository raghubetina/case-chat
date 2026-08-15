class HomeController < ApplicationController
  # Nobody stays here. Signed-in visitors have somewhere to be, and everybody
  # else is sent to the sign-in form, which carries the pitch beside it — a
  # landing page whose only control was a button reading "Sign in" cost a click
  # to reach the form behind it.
  def index
    return redirect_to cases_path if current_user

    redirect_to rodauth.login_path
  end
end
