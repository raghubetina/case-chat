require "test_helper"
require_relative "domain_test_helper"

# == Schema Information
#
# Table name: users
#
#  id         :uuid             not null, primary key
#  email      :string           not null
#  full_name  :string           not null
#  program    :string
#  status     :integer          default("unverified"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#
class UserTest < ActiveSupport::TestCase
  include DomainTestHelper

  test "cannot be destroyed while cases name them as author" do
    case_study = build_case_study
    author = case_study.author

    assert_not author.destroy
    assert author.errors.of_kind?(:base, :"restrict_dependent_destroy.has_many")
    assert User.exists?(author.id)
  end

  test "destroys enrollments and their threads with it" do
    conversation = build_conversation
    student = conversation.enrollment.user
    build_message(conversation: conversation)

    student.destroy!

    assert_equal 0, Enrollment.count
    assert_equal 0, Conversation.count
    assert_equal 0, Message.count
  end
end
