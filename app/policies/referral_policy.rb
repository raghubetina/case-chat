# Referral rules are the case's map: which contact hands the student off to
# whom, and on what cue. Authors only, in every direction.
class ReferralPolicy < ApplicationPolicy
  def index? = signed_in?

  def show? = author?

  def new? = signed_in?

  def create? = authors_contact_id?(record.referring_contact_id) &&
    authors_contact_id?(record.referred_contact_id)

  def update? = author?

  def destroy? = author?

  relation_scope do |relation|
    next relation.none unless signed_in?

    relation.where(
      referring_contact_id: Contact.where(
        case_study_id: CaseStudy.where(author_id: user.id).select(:id)
      ).select(:id)
    )
  end

  private

  def author? = author_of?(record.referring_contact.case_study)
end
