require "test_helper"
require_relative "domain_test_helper"

# == Schema Information
#
# Table name: case_studies
#
#  id         :uuid             not null, primary key
#  assignment :text
#  background :text
#  course     :string
#  due_at     :datetime
#  join_code  :string(32)
#  published  :boolean          default(FALSE), not null
#  title      :string(200)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  author_id  :uuid             not null
#
# Indexes
#
#  index_case_studies_on_author_id  (author_id)
#  index_case_studies_on_join_code  (join_code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (author_id => users.id) ON DELETE => restrict
#
class CaseStudyTest < ActiveSupport::TestCase
  include DomainTestHelper

  should belong_to(:author).class_name("User")
  should have_many(:contacts).dependent(:destroy)
  should have_many(:enrollments).dependent(:destroy)
  should have_many(:documents).dependent(:destroy)
  should have_one(:case_draft).dependent(:destroy)

  should validate_presence_of(:title)
  should validate_length_of(:title).is_at_most(200)
  should validate_length_of(:join_code).is_at_most(32)

  # Codes are handed out on paper and typed back in, so how they are typed must
  # not matter. Normalizing on the way in is what makes the uniqueness index
  # case-insensitive too.
  test "normalizes join codes to trimmed uppercase" do
    case_study = build_case_study
    case_study.update!(join_code: "  calder-04 ")

    assert_equal "CALDER-04", case_study.join_code
  end

  test "rejects a join code already taken in another case" do
    author = build_user
    build_case_study(author: author).update!(join_code: "CALDER-04")
    duplicate = CaseStudy.new(title: "Other", author: author, join_code: "calder-04")

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:join_code, :taken)
  end
end
