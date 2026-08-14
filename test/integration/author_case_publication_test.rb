require "test_helper"

class AuthorCasePublicationTest < ActionDispatch::IntegrationTest
  PASSWORD = "a secure prototype password"

  test "requires an account to publish" do
    case_record = create_case

    post "/author/cases/#{case_record.id}/publish"

    assert_redirected_to "/login"
    assert_equal "draft", case_record.reload.status
  end

  test "publishes an authored ready case" do
    author = create_account
    case_record = create_case(author:)
    stakeholder = create_stakeholder(case_record:)
    sign_in(author)

    post "/author/cases/#{case_record.id}/publish"

    assert_redirected_to "/author/cases/#{case_record.id}/edit"
    assert_equal I18n.t("author.cases.publication.flash.published"), flash[:notice]
    assert_equal "published", case_record.reload.status
    assert case_record.published_configuration.fetch("stakeholders").key?(stakeholder.id)
  end

  test "saves submitted case fields before publishing that configuration" do
    author = create_account
    case_record = create_case(author:)
    create_stakeholder(case_record:)
    sign_in(author)

    patch "/author/cases/#{case_record.id}", params: {
      publish_after_save: "1",
      case: {
        title: "A revised case",
        background: "Facts submitted with the publication action.",
        assignment: "Recommend a response to the revised facts."
      }
    }

    assert_redirected_to "/author/cases/#{case_record.id}/edit"
    case_record.reload
    assert_equal "published", case_record.status
    assert_equal "A revised case", case_record.title
    assert_equal "Facts submitted with the publication action.", case_record.background
    assert_equal "Recommend a response to the revised facts.", case_record.assignment
    assert_equal "Facts submitted with the publication action.",
      case_record.published_configuration.dig("case", "background")
  end

  test "keeps a submitted incomplete draft without publishing it" do
    author = create_account
    case_record = create_case(author:)
    create_stakeholder(case_record:)
    sign_in(author)

    patch "/author/cases/#{case_record.id}", params: {
      publish_after_save: "1",
      case: {
        title: case_record.title,
        background: "",
        assignment: case_record.assignment
      }
    }

    assert_response :unprocessable_entity
    assert_select "#flash_alerts[role='alert'] span",
      text: "Draft saved, but not published. Complete the checklist below."
    assert_select "#publication-panel" do
      assert_select "a", text: "Add the case background"
    end
    case_record.reload
    assert_equal "", case_record.background
    assert_equal "draft", case_record.status
    assert_nil case_record.published_configuration
  end

  test "keeps the previous publication pinned when submitted changes are incomplete" do
    author = create_account
    case_record = create_case(author:)
    stakeholder = create_stakeholder(case_record:)
    publish_case(case_record)
    case_record.reload
    previous_configuration = case_record.published_configuration.deep_dup
    previous_published_at = case_record.published_at
    previous_stakeholder_lock = stakeholder.reload.publication_locked_at
    sign_in(author)

    patch "/author/cases/#{case_record.id}", params: {
      publish_after_save: "1",
      case: {
        title: case_record.title,
        background: "",
        assignment: case_record.assignment
      }
    }

    assert_response :unprocessable_entity
    assert_select "#publication-panel" do
      assert_select "a", text: "Add the case background"
      assert_select "h3", text: "Your changes are a new draft"
    end
    case_record.reload
    assert_equal "", case_record.background
    assert_equal "published", case_record.status
    assert_equal previous_configuration, case_record.published_configuration
    assert_equal previous_published_at, case_record.published_at
    assert_equal previous_stakeholder_lock, stakeholder.reload.publication_locked_at
  end

  test "keeps invalid submitted fields on screen without saving or publishing them" do
    author = create_account
    case_record = create_case(author:)
    create_stakeholder(case_record:)
    original_background = case_record.background
    sign_in(author)

    patch "/author/cases/#{case_record.id}", params: {
      publish_after_save: "1",
      case: {
        title: "   ",
        background: "An invalid edit that must remain on screen.",
        assignment: case_record.assignment
      }
    }

    assert_response :unprocessable_entity
    assert_select "textarea[name='case[background]']", text: "An invalid edit that must remain on screen."
    assert_select "#publication-panel", text: /Save a valid draft first/
    case_record.reload
    assert_equal original_background, case_record.background
    assert_equal "draft", case_record.status
    assert_nil case_record.published_configuration
  end

  test "reports an unchanged publication without writing it again" do
    author = create_account
    case_record = create_case(author:)
    create_stakeholder(case_record:)
    publish_case(case_record)
    case_record.reload
    published_at = case_record.published_at
    case_record.update_columns(updated_at: 2.days.ago)
    stale_updated_at = case_record.reload.updated_at
    sign_in(author)

    post "/author/cases/#{case_record.id}/publish"

    assert_redirected_to "/author/cases/#{case_record.id}/edit"
    assert_equal I18n.t("author.cases.publication.flash.current"), flash[:notice]
    assert_equal published_at, case_record.reload.published_at
    assert_equal stale_updated_at, case_record.updated_at
  end

  test "renders readiness problems without changing state or locks" do
    author = create_account
    case_record = create_case(author:, background: "")
    stakeholder = create_stakeholder(case_record:)
    case_record.update_columns(updated_at: 2.days.ago)
    stale_updated_at = case_record.reload.updated_at
    sign_in(author)

    post "/author/cases/#{case_record.id}/publish"

    assert_response :unprocessable_entity
    assert_select "#publication-panel" do
      assert_select "a", text: "Add the case background"
      assert_select "form[action='/author/cases/#{case_record.id}/publish']", count: 0
    end
    assert_equal "draft", case_record.reload.status
    assert_nil case_record.published_configuration
    assert_nil case_record.published_at
    assert_equal stale_updated_at, case_record.updated_at
    assert_nil stakeholder.reload.publication_locked_at
  end

  test "returns not found for another author's or an enrolled case" do
    author = create_account
    foreign_case = create_case
    create_stakeholder(case_record: foreign_case)
    enrolled_case = create_case
    create_stakeholder(case_record: enrolled_case)
    enroll(case_record: enrolled_case, user: author)
    sign_in(author)

    [foreign_case, enrolled_case].each do |case_record|
      with_rendered_exceptions do
        post "/author/cases/#{case_record.id}/publish"
      end

      assert_response :not_found
      assert_equal "draft", case_record.reload.status
      assert_nil case_record.published_configuration
    end
  end

  private

  def create_account
    User.create!(
      full_name: "Avery Author",
      email: "account-#{SecureRandom.uuid}@example.test",
      password: PASSWORD
    )
  end

  def sign_in(user)
    post "/login", params: {email: user.email, password: PASSWORD}
    assert_redirected_to "/"
  end

  def with_rendered_exceptions
    env_config = Rails.application.env_config
    previous_show_exceptions = env_config["action_dispatch.show_exceptions"]
    previous_show_detailed_exceptions = env_config["action_dispatch.show_detailed_exceptions"]
    env_config["action_dispatch.show_exceptions"] = :all
    env_config["action_dispatch.show_detailed_exceptions"] = false
    yield
  ensure
    env_config["action_dispatch.show_exceptions"] = previous_show_exceptions
    env_config["action_dispatch.show_detailed_exceptions"] = previous_show_detailed_exceptions
  end
end
