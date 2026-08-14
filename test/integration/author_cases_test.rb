require "test_helper"

class AuthorCasesTest < ActionDispatch::IntegrationTest
  PASSWORD = "a secure prototype password"

  test "requires an account for the author case workspace" do
    get "/author/cases"

    assert_redirected_to "/login"
  end

  test "lists only authored cases with the most recently edited first" do
    author = create_account(full_name: "Avery Author")
    older_case = create_case(author:, title: "Older authored case")
    newer_case = create_case(author:, title: "Newer authored case")
    enrolled_case = create_case(title: "Enrolled learner case")
    foreign_case = create_case(title: "Someone else's case")
    enroll(case_record: enrolled_case, user: author)
    older_case.update_columns(updated_at: 2.days.ago)
    newer_case.update_columns(updated_at: 1.day.ago)
    sign_in(author)

    get "/author/cases"

    assert_response :success
    assert_includes response.body, older_case.title
    assert_includes response.body, newer_case.title
    refute_includes response.body, enrolled_case.title
    refute_includes response.body, foreign_case.title
    assert_operator response.body.index(newer_case.title), :<, response.body.index(older_case.title)
    assert_select "h2 a:not([aria-label])", text: newer_case.title, count: 1
  end

  test "keeps the authored list bounded across pages without leaking other cases" do
    author = create_account(full_name: "Avery Author")
    edited_at = Time.zone.parse("2026-08-14 09:00")
    authored_cases = 21.times.map do |index|
      create_case(author:, title: format("Authored case %02d", index)).tap do |case_record|
        case_record.update_columns(updated_at: edited_at + index.minutes)
      end
    end
    foreign_case = create_case(title: "Foreign page case")
    enrolled_case = create_case(title: "Enrolled page case")
    enroll(case_record: enrolled_case, user: author)
    sign_in(author)

    get "/author/cases"

    assert_response :success
    assert_select ".case-card", count: 20
    assert_includes response.body, authored_cases.last.title
    refute_includes response.body, authored_cases.first.title
    refute_includes response.body, foreign_case.title
    refute_includes response.body, enrolled_case.title

    get "/author/cases", params: {page: 2}

    assert_response :success
    assert_select ".case-card", count: 1
    assert_includes response.body, authored_cases.first.title
    refute_includes response.body, authored_cases.last.title
    refute_includes response.body, foreign_case.title
    refute_includes response.body, enrolled_case.title

    get "/author/cases", params: {page: 99}

    assert_response :success
    assert_select ".case-card", count: 0
    assert_select ".author-empty-state", count: 0
    assert_select ".pagination", count: 1
    assert_select ".pagination a", minimum: 1
  end

  test "creates a draft owned by the signed-in author from allowed fields only" do
    author = create_account(full_name: "Avery Author")
    another_user = create_account(full_name: "Another Author")
    sign_in(author)

    assert_difference -> { Case.count }, 1 do
      post "/author/cases", params: {
        case: {
          title: "Vesta operating decision",
          background: "Shared kitchen capacity is tight.",
          assignment: "Recommend an operating policy.",
          author_id: another_user.id,
          status: "archived",
          published_configuration: {"private" => true},
          published_at: Time.current
        }
      }
    end

    case_record = Case.order(:created_at).last
    assert_redirected_to "/author/cases/#{case_record.id}/edit"
    assert_equal author.id, case_record.author_id
    assert_equal "Vesta operating decision", case_record.title
    assert_equal "draft", case_record.status
    assert_nil case_record.published_configuration
    assert_nil case_record.published_at
  end

  test "renders validation feedback without creating an invalid draft" do
    author = create_account(full_name: "Avery Author")
    sign_in(author)

    assert_no_difference -> { Case.count } do
      post "/author/cases", params: {
        case: {
          title: "  ",
          background: "Shared kitchen capacity is tight.",
          assignment: "Recommend an operating policy."
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Title"
  end

  test "updates an authored published draft without changing its publication" do
    author = create_account(full_name: "Avery Author")
    case_record = create_case(author:)
    create_stakeholder(case_record:)
    publish_case(case_record)
    case_record.reload
    published_configuration = case_record.published_configuration.deep_dup
    published_at = case_record.published_at
    sign_in(author)

    patch "/author/cases/#{case_record.id}", params: {
      case: {
        title: "Updated title",
        background: "The kitchen now has an expediter.",
        assignment: "Recommend the next operating policy.",
        status: "archived",
        published_configuration: {"tampered" => true},
        published_at: 1.year.from_now
      }
    }

    assert_redirected_to "/author/cases/#{case_record.id}/edit"
    case_record.reload
    assert_equal "Updated title", case_record.title
    assert_equal "The kitchen now has an expediter.", case_record.background
    assert_equal "Recommend the next operating policy.", case_record.assignment
    assert_equal "published", case_record.status
    assert_equal published_configuration, case_record.published_configuration
    assert_equal published_at, case_record.published_at
  end

  test "leaves the stored draft and publication unchanged after an invalid edit" do
    author = create_account(full_name: "Avery Author")
    case_record = create_case(author:)
    create_stakeholder(case_record:)
    publish_case(case_record)
    case_record.reload
    original_attributes = case_record.attributes.slice(
      "title",
      "background",
      "assignment",
      "status",
      "published_configuration",
      "published_at"
    ).deep_dup
    sign_in(author)

    patch "/author/cases/#{case_record.id}", params: {
      case: {
        title: "  ",
        background: "This must not persist.",
        assignment: "This must not persist either."
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "Title"
    assert_select "textarea[name='case[background]']", text: "This must not persist."
    assert_select "textarea[name='case[assignment]']", text: "This must not persist either."
    assert_equal original_attributes, case_record.reload.attributes.slice(*original_attributes.keys)
  end

  test "returns not found for another user's case or an enrolled case" do
    author = create_account(full_name: "Avery Author")
    foreign_case = create_case(title: "Foreign case")
    enrolled_case = create_case(title: "Enrolled case")
    enroll(case_record: enrolled_case, user: author)
    sign_in(author)

    [foreign_case, enrolled_case].each do |case_record|
      with_rendered_exceptions do
        get "/author/cases/#{case_record.id}/edit"
      end
      assert_response :not_found

      with_rendered_exceptions do
        patch "/author/cases/#{case_record.id}", params: {
          case: {title: "Unauthorized edit"}
        }
      end
      assert_response :not_found
      refute_equal "Unauthorized edit", case_record.reload.title
    end
  end

  private

  def create_account(full_name:)
    User.create!(
      full_name:,
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
