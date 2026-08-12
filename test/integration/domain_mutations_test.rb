require "test_helper"
require_relative "../models/domain_test_helper"

class DomainMutationsTest < ActionDispatch::IntegrationTest
  include DomainTestHelper

  setup do
    @author = register_user(full_name: "Rachel Okonkwo")
    sign_in_as @author
  end

  test "creates a contact with its system prompt through the form" do
    case_study = CaseStudy.create!(title: "Calder Instruments", author: @author)

    assert_difference "Contact.count", 1 do
      post contacts_path, params: {
        contact: {
          full_name: "Dana Whitfield",
          role_title: "Chief Financial Officer",
          description: "Owns the board narrative.",
          system_prompt: "You are Dana Whitfield. Speak in numbers.",
          in_starting_directory: "1",
          case_study_id: case_study.id
        }
      }
    end

    contact = Contact.order(:created_at).last
    assert_redirected_to contact_path(contact)
    assert contact.in_starting_directory
  end

  test "re-renders the form when a contact lacks a system prompt" do
    case_study = CaseStudy.create!(title: "Calder Instruments", author: @author)

    assert_no_difference "Contact.count" do
      post contacts_path, params: {
        contact: {full_name: "Dana", role_title: "CFO", case_study_id: case_study.id}
      }
    end

    assert_response :unprocessable_content
  end

  test "creates a message stamping who spoke" do
    contact = build_contact(case_study: CaseStudy.create!(title: "Calder", author: @author))
    enrollment = Enrollment.create!(user: @author, case_study: contact.case_study)
    conversation = Conversation.create!(enrollment: enrollment, contact: contact)

    assert_difference "Message.count", 1 do
      post messages_path, params: {
        message: {
          body: "Why did margin fall?",
          sent_at: Time.current.iso8601,
          from_contact: "0",
          conversation_id: conversation.id
        }
      }
    end

    assert_equal false, Message.order(:created_at).last.from_contact
  end

  test "renders every extended form" do
    build_contact(case_study: CaseStudy.create!(title: "Calder", author: @author))

    %w[case_studies contacts documents referrals share_rules messages].each do |resource|
      get "/#{resource}/new"

      assert_response :success, "expected /#{resource}/new to render"
    end
  end
end
