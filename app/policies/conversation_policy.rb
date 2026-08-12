# A thread belongs to one run of a case by one student. The student owns it;
# the case's author may read it (that is what the cohort view is).
class ConversationPolicy < ApplicationPolicy
  def index? = signed_in?

  def show? = own? || author_of?(record.contact.case_study)

  def new? = signed_in?

  # A thread is opened by the student whose run it belongs to.
  def create? = owns_enrollment_id?(record.enrollment_id) &&
    Contact.exists?(id: record.contact_id)

  def update? = own?

  def destroy? = own? || author_of?(record.contact.case_study)

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
