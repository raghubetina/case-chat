class DocumentPolicy < ApplicationPolicy
  def index? = signed_in?

  # Given to everyone at the start, or earned from a contact who shared it.
  def show? = author_of?(record.case_study) || given_at_start? || shared_with_student?

  def new? = signed_in?

  def create? = authors_case_id?(record.case_study_id)

  def update? = author_of?(record.case_study)

  def destroy? = author_of?(record.case_study)

  relation_scope do |relation|
    next relation.none unless signed_in?

    enrolled_case_ids = Enrollment.where(user_id: user.id).select(:case_study_id)

    authored = relation.where(case_study_id: CaseStudy.where(author_id: user.id).select(:id))
    handed_out = relation.where(given_at_start: true, case_study_id: enrolled_case_ids)
    earned = relation.where(
      id: DocumentShare.where(
        message_id: Message.where(
          conversation_id: Conversation.where(
            enrollment_id: Enrollment.where(user_id: user.id).select(:id)
          ).select(:id)
        ).select(:id)
      ).select(:document_id)
    )

    authored.or(handed_out).or(earned)
  end

  private

  def given_at_start? = record.given_at_start? && student_reading?(record.case_study)

  def shared_with_student?
    return false unless student_reading?(record.case_study)

    DocumentShare.exists?(
      document_id: record.id,
      message_id: Message.where(
        conversation_id: Conversation.where(
          enrollment_id: Enrollment.where(user_id: user.id, case_study_id: record.case_study_id).select(:id)
        ).select(:id)
      ).select(:id)
    )
  end
end
