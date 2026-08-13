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

  # A case without its author is unownable, so authoring blocks deletion while
  # being a student does not.
  should have_many(:authored_cases).class_name("CaseStudy")
    .with_foreign_key("author_id").dependent(:restrict_with_error)
  should have_many(:enrollments).dependent(:destroy)

  should validate_presence_of(:full_name)
  should validate_presence_of(:email)

  test "normalizes email to trimmed lowercase" do
    user = User.create!(full_name: "Jordan Lin", email: "  Jordan@Example.Test ", status: 2)

    assert_equal "jordan@example.test", user.email
  end

  test "rejects a duplicate email regardless of case" do
    build_user.update!(email: "jordan@example.test")
    duplicate = User.new(full_name: "Other", email: "JORDAN@example.test", status: 2)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:email, :taken)
  end
end
