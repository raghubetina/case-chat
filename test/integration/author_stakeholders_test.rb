require "test_helper"

class AuthorStakeholdersTest < ActionDispatch::IntegrationTest
  PASSWORD = "a secure prototype password"

  test "requires an account for the author stakeholder workspace" do
    case_record = create_case

    get "/author/cases/#{case_record.id}/stakeholders"

    assert_redirected_to "/login"
  end

  test "lists only the selected authored case stakeholders across bounded pages" do
    author = create_account(full_name: "Avery Author")
    case_record = create_case(author:)
    stakeholders = 21.times.map do |index|
      create_stakeholder(
        case_record:,
        name: format("Stakeholder %02d", index),
        role_title: "Interview subject"
      )
    end
    other_case = create_case(author:)
    other_stakeholder = create_stakeholder(case_record: other_case, name: "Other case stakeholder")
    sign_in(author)

    get "/author/cases/#{case_record.id}/stakeholders"

    assert_response :success
    stakeholders.first(20).each { |stakeholder| assert_includes response.body, stakeholder.name }
    refute_includes response.body, stakeholders.last.name
    refute_includes response.body, other_stakeholder.name

    get "/author/cases/#{case_record.id}/stakeholders", params: {page: 2}

    assert_response :success
    assert_includes response.body, stakeholders.last.name
    stakeholders.first(20).each { |stakeholder| refute_includes response.body, stakeholder.name }
    refute_includes response.body, other_stakeholder.name
  end

  test "creates an authored stakeholder from editable fields only" do
    author = create_account(full_name: "Avery Author")
    case_record = create_case(author:)
    other_case = create_case(author:)
    case_record.update_columns(updated_at: 2.days.ago)
    stale_updated_at = case_record.reload.updated_at
    sign_in(author)

    assert_difference -> { Stakeholder.count }, 1 do
      post "/author/cases/#{case_record.id}/stakeholders", params: {
        stakeholder: {
          name: "June Ellery",
          role_title: "General manager",
          description: "Owns the operating decision.",
          instructions: "Answer only from June's knowledge.",
          knows_case_background: "0",
          available_at_start: "1",
          included_in_publication: "0",
          provider: "anthropic",
          model_id: "claude-sonnet-4-5",
          case_id: other_case.id,
          provider_settings: {temperature: 2},
          publication_locked_at: 1.year.from_now
        }
      }
    end

    stakeholder = case_record.stakeholders.order(:created_at).last
    assert_redirected_to "/author/cases/#{case_record.id}/stakeholders"
    assert_equal case_record.id, stakeholder.case_id
    assert_equal "June Ellery", stakeholder.name
    assert_equal "General manager", stakeholder.role_title
    assert_equal "Owns the operating decision.", stakeholder.description
    assert_equal "Answer only from June's knowledge.", stakeholder.instructions
    refute stakeholder.knows_case_background
    assert stakeholder.available_at_start
    refute stakeholder.included_in_publication
    assert_equal "anthropic", stakeholder.provider
    assert_equal "claude-sonnet-4-5", stakeholder.model_id
    assert_equal({}, stakeholder.provider_settings)
    assert_nil stakeholder.publication_locked_at
    assert_operator case_record.reload.updated_at, :>, stale_updated_at
  end

  test "rejects an invalid stakeholder without touching the case" do
    author = create_account(full_name: "Avery Author")
    case_record = create_case(author:)
    case_record.update_columns(updated_at: 2.days.ago)
    stale_updated_at = case_record.reload.updated_at
    sign_in(author)

    assert_no_difference -> { Stakeholder.count } do
      post "/author/cases/#{case_record.id}/stakeholders", params: {
        stakeholder: {
          name: " ",
          role_title: " ",
          description: "Keep this typed value.",
          provider: "anthropic"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Keep this typed value."
    assert_equal stale_updated_at, case_record.reload.updated_at
  end

  test "updates a stakeholder draft without changing published or attempt snapshots" do
    author = create_account(full_name: "Avery Author")
    case_record = create_case(author:)
    stakeholder = create_stakeholder(case_record:)
    publish_case(case_record)
    attempt = start_attempt(case_record:)
    case_record.reload
    stakeholder.reload
    publication = case_record.attributes.slice(
      "status",
      "published_configuration",
      "published_at"
    ).deep_dup
    attempt_snapshot = attempt.configuration_snapshot.deep_dup
    publication_locked_at = stakeholder.publication_locked_at
    other_case = create_case(author:)
    stale_updated_at = 2.days.ago
    case_record.update_columns(updated_at: stale_updated_at)
    sign_in(author)

    patch "/author/cases/#{case_record.id}/stakeholders/#{stakeholder.id}", params: {
      stakeholder: {
        name: "June Ellery, revised",
        role_title: "Chief operating officer",
        description: "Now owns the revised draft decision.",
        instructions: "Use the new draft instructions.",
        knows_case_background: "0",
        available_at_start: "0",
        included_in_publication: "0",
        provider: "anthropic",
        model_id: "claude-sonnet-4-5",
        case_id: other_case.id,
        provider_settings: {tampered: true},
        publication_locked_at: nil
      }
    }

    assert_redirected_to "/author/cases/#{case_record.id}/stakeholders"
    stakeholder.reload
    assert_equal "June Ellery, revised", stakeholder.name
    assert_equal "Chief operating officer", stakeholder.role_title
    assert_equal "Now owns the revised draft decision.", stakeholder.description
    assert_equal "Use the new draft instructions.", stakeholder.instructions
    refute stakeholder.knows_case_background
    refute stakeholder.available_at_start
    refute stakeholder.included_in_publication
    assert_equal "anthropic", stakeholder.provider
    assert_equal "claude-sonnet-4-5", stakeholder.model_id
    assert_equal case_record.id, stakeholder.case_id
    assert_equal({}, stakeholder.provider_settings)
    assert_equal publication_locked_at, stakeholder.publication_locked_at
    assert_equal publication, case_record.reload.attributes.slice(*publication.keys)
    assert_equal attempt_snapshot, attempt.reload.configuration_snapshot
    assert_operator case_record.updated_at, :>, stale_updated_at
  end

  test "leaves stored stakeholder and case state unchanged after an invalid edit" do
    author = create_account(full_name: "Avery Author")
    case_record = create_case(author:)
    stakeholder = create_stakeholder(case_record:)
    original = stakeholder.attributes.slice(*Stakeholder::DRAFT_EDITABLE_ATTRIBUTES.map(&:to_s)).deep_dup
    case_record.update_columns(updated_at: 2.days.ago)
    stale_updated_at = case_record.reload.updated_at
    sign_in(author)

    patch "/author/cases/#{case_record.id}/stakeholders/#{stakeholder.id}", params: {
      stakeholder: {
        name: " ",
        role_title: "Changed role",
        description: "This must not persist.",
        instructions: "Neither should this.",
        provider: "anthropic"
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "This must not persist."
    assert_equal original, stakeholder.reload.attributes.slice(*original.keys)
    assert_equal stale_updated_at, case_record.reload.updated_at
  end

  test "returns not found for foreign parent and child identifiers" do
    author = create_account(full_name: "Avery Author")
    own_case = create_case(author:)
    own_stakeholder = create_stakeholder(case_record: own_case)
    foreign_case = create_case
    foreign_stakeholder = create_stakeholder(case_record: foreign_case)
    enrolled_case = create_case
    create_stakeholder(case_record: enrolled_case)
    enroll(case_record: enrolled_case, user: author)
    sign_in(author)

    [foreign_case, enrolled_case].each do |case_record|
      with_rendered_exceptions do
        get "/author/cases/#{case_record.id}/stakeholders"
      end
      assert_response :not_found
    end

    with_rendered_exceptions do
      get "/author/cases/#{own_case.id}/stakeholders/#{foreign_stakeholder.id}/edit"
    end
    assert_response :not_found

    with_rendered_exceptions do
      patch "/author/cases/#{own_case.id}/stakeholders/#{foreign_stakeholder.id}", params: {
        stakeholder: {name: "Unauthorized edit"}
      }
    end
    assert_response :not_found
    refute_equal "Unauthorized edit", foreign_stakeholder.reload.name
    assert_equal "June Ellery", own_stakeholder.reload.name
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
