class EnrollmentPolicy < ApplicationPolicy
  def index? = signed_in?

  def show? = own? || author_of?(record.case_study)

  def new? = signed_in?

  # Enroll yourself, or enroll anyone into a case you author.
  def create? = own? || authors_case_id?(record.case_study_id)

  def update? = author_of?(record.case_study)

  def destroy? = own? || author_of?(record.case_study)

  relation_scope do |relation|
    next relation.none unless signed_in?

    relation.where(user_id: user.id).or(
      relation.where(case_study_id: CaseStudy.where(author_id: user.id).select(:id))
    )
  end

  private

  def own? = signed_in? && record.user_id == user.id
end
