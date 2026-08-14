require "test_helper"

class AuthenticatedControllerTest < ActionController::TestCase
  class PermitAllPolicy
    def initialize(*)
    end

    def show?
      true
    end
  end

  class PassthroughScope
    def initialize(_user, scope)
      @scope = scope
    end

    def resolve
      @scope
    end
  end

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "anonymous/index", to: "anonymous#index"
      get "anonymous/show", to: "anonymous#show"
    end

    @controller = Class.new(AuthenticatedController) do
      skip_before_action :authenticate

      def index
        perform_pundit_check
        head :ok
      end

      def show
        perform_pundit_check
        head :ok
      end

      private

      def current_user
        :test_user
      end

      def perform_pundit_check
        if params[:check] == "authorize"
          authorize :probe, :show?, policy_class: AuthenticatedControllerTest::PermitAllPolicy
        else
          policy_scope [], policy_scope_class: AuthenticatedControllerTest::PassthroughScope
        end
      end
    end.new
  end

  test "accepts a policy scope for an index action" do
    get :index, params: {check: "scope"}

    assert_response :success
  end

  test "rejects record authorization as a substitute for an index scope" do
    assert_raises(Pundit::PolicyScopingNotPerformedError) do
      get :index, params: {check: "authorize"}
    end
  end

  test "accepts record authorization for a member action" do
    get :show, params: {check: "authorize"}

    assert_response :success
  end

  test "rejects a policy scope as a substitute for member authorization" do
    assert_raises(Pundit::AuthorizationNotPerformedError) do
      get :show, params: {check: "scope"}
    end
  end

  test "redirects an unauthenticated subclass action to login" do
    @controller = Class.new(AuthenticatedController) do
      def show
        authorize :probe, :show?, policy_class: AuthenticatedControllerTest::PermitAllPolicy
        head :ok
      end
    end.new

    get :show

    assert_redirected_to "/login"
  end
end
