require "test_helper"

class CaseStudyTest < ActiveSupport::TestCase
  test "rejects a title longer than the stored limit" do
    case_study = CaseStudy.new(author: author, title: "x" * 201)

    refute case_study.valid?
    assert_includes case_study.errors.details[:title], error: :too_long, count: 200
  end

  test "accepts and stores a title at the limit" do
    case_study = CaseStudy.create!(author: persisted_author, title: "x" * 200)

    assert_equal 200, case_study.reload.title.length
  end

  test "rejects a join code longer than the stored limit" do
    case_study = CaseStudy.new(author: author, title: "Case", join_code: "x" * 33)

    refute case_study.valid?
    assert_includes case_study.errors.details[:join_code], error: :too_long, count: 32
  end

  test "accepts and stores a join code at the limit" do
    case_study = CaseStudy.create!(author: persisted_author, title: "Case", join_code: "x" * 32)

    assert_equal 32, case_study.reload.join_code.length
  end

  private

  def author
    User.new(full_name: "Author")
  end

  def persisted_author
    User.create!(full_name: "Author", email: "author-#{SecureRandom.hex(4)}@example.test")
  end
end
