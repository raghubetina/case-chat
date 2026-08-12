module DomainTestHelper
  def build_user
    User.create!(full_name: "Jordan Lin", email: "user-#{SecureRandom.hex(4)}@example.test", status: 2)
  end

  def build_case_study(author: build_user)
    CaseStudy.create!(title: "Calder Instruments", author: author)
  end

  def build_contact(case_study: build_case_study, full_name: "Dana Whitfield")
    Contact.create!(
      full_name: full_name,
      role_title: "Chief Financial Officer",
      system_prompt: "You are Dana Whitfield. Speak in numbers.",
      case_study: case_study
    )
  end

  def build_enrollment(case_study: build_case_study, user: build_user)
    Enrollment.create!(user: user, case_study: case_study)
  end

  def build_conversation(contact: build_contact)
    enrollment = build_enrollment(case_study: contact.case_study)
    Conversation.create!(enrollment: enrollment, contact: contact)
  end

  def build_message(conversation: build_conversation)
    Message.create!(conversation: conversation, body: "Why did margin fall?", sent_at: Time.current, from_contact: false)
  end

  def build_document(case_study: build_case_study)
    Document.create!(file_name: "Calder_Segment_PL_FY24.xlsx", case_study: case_study)
  end
end
