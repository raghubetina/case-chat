class IntroductionPolicy < ApplicationPolicy
  def index? = signed_in?

  def show? = own? || author_of?(record.contact.case_study)

  def new? = signed_in?

  def create? = owns_enrollment_id?(record.enrollment_id) ||
    authors_contact_id?(record.contact_id)

  def update? = false

  def destroy? = author_of?(record.contact.case_study)

  relation_scope do |relation|
    next relation.none unless signed_in?

    relation.where(enrollment_id: Enrollment.where(user_id: user.id).select(:id)).or(
      relation.where(
        contact_id: Contact.where(case_study_id: CaseStudy.where(author_id: user.id).select(:id)).select(:id)
      )
    )
  end

  private

  def own? = signed_in? && record.enrollment.user_id == user.id
end
