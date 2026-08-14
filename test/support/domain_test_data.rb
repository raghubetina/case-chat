module DomainTestData
  def create_user(full_name: "Avery Author", email: nil)
    User.create!(
      full_name:,
      email: email || "user-#{SecureRandom.uuid}@example.test"
    )
  end

  def create_case(author: create_user, title: "Vesta decision", background: "Shared kitchen capacity is tight.", assignment: "Recommend an operating policy.")
    Case.create!(author:, title:, background:, assignment:)
  end

  def create_stakeholder(case_record:, name: "June Ellery", role_title: "General manager", **attributes)
    Stakeholder.create!(
      {
        case: case_record,
        name:,
        role_title:,
        description: "Owns the operating decision.",
        instructions: "Answer only from your own knowledge.",
        available_at_start: true,
        provider: "openai",
        model_id: "gpt-5-mini"
      }.merge(attributes)
    )
  end

  def create_case_document(case_record:, title: "Checks", body: "check,data\n1,42\n", **attributes)
    document = CaseDocument.create!(
      {
        case: case_record,
        title:,
        description: "Friday checks",
        learner_text: body,
        available_at_start: false
      }.merge(attributes)
    )
    document.file.attach(
      io: StringIO.new(body),
      filename: "#{title.parameterize}.csv",
      content_type: "text/csv"
    )
    document
  end

  def create_publishable_case
    case_record = create_case
    stakeholder = create_stakeholder(case_record:)
    document = create_case_document(case_record:)
    bundle = DocumentBundle.create!(
      stakeholder:,
      name: "Friday evidence",
      guidance: "Share when the learner asks for evidence."
    )
    DocumentBundleItem.create!(document_bundle: bundle, case_document: document, position: 1)

    {case: case_record, stakeholder:, document:, bundle:}
  end

  def publish_case(case_record)
    Cases::Publish.call(case_record:).snapshot
  end

  def enroll(case_record:, user: create_user(full_name: "Lee Learner"), join_code: nil)
    cohort = Cohort.create!(
      case: case_record,
      name: "Fall pilot",
      join_code: join_code || "PILOT-#{SecureRandom.hex(3)}"
    )
    Enrollment.create!(user:, cohort:)
  end

  def start_attempt(case_record:, user: nil)
    enrollment = enroll(case_record:, user: user || create_user(full_name: "Lee Learner"))
    Attempts::Reset.call(enrollment:)
  end

  def complete_assistant_message(attempt:, stakeholder:)
    conversation = Conversations::StartLearner.call(attempt:, stakeholder_id: stakeholder.id)
    next_position = Message.where(conversation_id: conversation.id).maximum(:position).to_i + 1

    Message.create!(
      conversation:,
      position: next_position,
      role: "assistant",
      status: "complete",
      content: "I can connect you with the right person."
    )
  end
end

ActiveSupport.on_load(:active_support_test_case) { include DomainTestData }
