# Roles in Case Chat are relational, not a column: you are an author because a
# Case names you, and a student because an Enrollment does. Every policy below
# resolves permission by walking those relationships.
class ApplicationPolicy < ActionPolicy::Base
  authorize :user, allow_nil: true

  private

  def signed_in?
    user.present?
  end

  def author_of?(case_study)
    signed_in? && case_study.author_id == user.id
  end

  # An enrollment is one run of a case by one student.
  def enrolled_in?(case_study)
    signed_in? && Enrollment.exists?(user_id: user.id, case_study_id: case_study.id)
  end

  # Students only reach a case's contents once the author publishes it.
  def student_reading?(case_study)
    case_study.published? && enrolled_in?(case_study)
  end

  # `create?` runs against an unsaved record whose associations are not loaded,
  # so resolve ownership by the foreign key the form submitted rather than by
  # walking the association (which strict_loading correctly refuses).
  def authors_case_id?(case_study_id)
    signed_in? && case_study_id.present? &&
      CaseStudy.exists?(id: case_study_id, author_id: user.id)
  end

  def authors_contact_id?(contact_id)
    signed_in? && contact_id.present? &&
      Contact.where(id: contact_id).where(
        case_study_id: CaseStudy.where(author_id: user.id).select(:id)
      ).exists?
  end

  def owns_enrollment_id?(enrollment_id)
    signed_in? && enrollment_id.present? &&
      Enrollment.exists?(id: enrollment_id, user_id: user.id)
  end
end
