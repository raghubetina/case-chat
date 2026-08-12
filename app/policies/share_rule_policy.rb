# When a contact hands over a document, and under what condition, is authoring
# material — a student who could read it would know exactly what to ask for.
class ShareRulePolicy < ApplicationPolicy
  def index? = signed_in?

  def show? = author?

  def new? = signed_in?

  def create? = authors_contact_id?(record.contact_id)

  def update? = author?

  def destroy? = author?

  relation_scope do |relation|
    next relation.none unless signed_in?

    relation.where(
      contact_id: Contact.where(case_study_id: CaseStudy.where(author_id: user.id).select(:id)).select(:id)
    )
  end

  private

  def author? = author_of?(record.contact.case_study)
end
