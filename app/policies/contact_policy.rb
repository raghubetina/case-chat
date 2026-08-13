class ContactPolicy < ApplicationPolicy
  def index? = signed_in?

  # A student may read a contact they have met; the system prompt is withheld
  # separately (see readable_by_student?), since it is the case's answer key.
  def show? = author_of?(record.case_study) || met_by_student?

  def new? = signed_in?

  def create? = authors_case_id?(record.case_study_id)

  def update? = author_of?(record.case_study)

  def destroy? = author_of?(record.case_study)

  relation_scope do |relation|
    next relation.none unless signed_in?

    authored = relation.where(case_study_id: CaseStudy.where(author_id: user.id).select(:id))
    met = relation.where(
      id: Introduction.where(enrollment_id: Enrollment.where(user_id: user.id).select(:id)).select(:contact_id)
    )
    starting = relation.where(
      in_starting_directory: true,
      case_study_id: Enrollment.where(user_id: user.id).select(:case_study_id)
    )

    authored.or(met).or(starting)
  end

  private

  # Everyone in the starting directory has been met by definition.
  def met_by_student?
    return false unless student_reading?(record.case_study)
    return true if record.in_starting_directory?

    Introduction.exists?(
      contact_id: record.id,
      enrollment_id: Enrollment.where(user_id: user.id, case_study_id: record.case_study_id).select(:id)
    )
  end
end
