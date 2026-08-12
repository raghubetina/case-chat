# Turns a reviewed draft into real records.
#
# Deliberately a separate step from drafting. A drafted system prompt is a guess
# about what a person withholds, and withholding is the entire design of a case
# — so nothing exists until an author has read it and said yes.
class CaseImport
  Result = Data.define(:case_study, :contacts, :referrals, :share_rules, :reachability)

  def initialize(case_study, draft, case_draft: nil)
    @case_study = case_study
    @draft = draft
    @case_draft = case_draft
  end

  def apply!
    ApplicationRecord.transaction do
      # Consuming the proposal inside the same transaction that applies it is
      # what makes a double-submitted accept harmless: the second one finds
      # nothing to accept instead of applying the same draft again.
      @case_draft&.destroy!
      update_case
      contacts = build_contacts
      referrals = build_referrals(contacts)
      share_rules = build_share_rules(contacts)

      Result.new(
        case_study: @case_study,
        contacts: contacts.values,
        referrals: referrals,
        share_rules: share_rules,
        # Reported rather than enforced: an author can fix an orphan in the cast
        # editor, and publishing already refuses while one exists.
        reachability: CaseReachability.new(@case_study).call
      )
    end
  end

  private

  def update_case
    @case_study.update!(
      title: @draft.title.presence || @case_study.title,
      course: @draft.course.presence || @case_study.course,
      background: @draft.background.presence || @case_study.background,
      assignment: @draft.assignment.presence || @case_study.assignment
    )
  end

  # Keyed by name because that is what the draft's referrals and share rules
  # refer to; re-importing updates the person rather than duplicating them.
  def build_contacts
    @draft.contacts.each_with_object({}) do |drafted, map|
      contact = Contact.find_or_initialize_by(case_study: @case_study, full_name: drafted.full_name)
      contact.assign_attributes(
        role_title: drafted.role_title,
        description: drafted.description,
        system_prompt: drafted.system_prompt,
        in_starting_directory: drafted.in_starting_directory
      )
      contact.save!
      map[drafted.full_name] = contact
    end
  end

  def build_referrals(contacts)
    @draft.referrals.filter_map do |drafted|
      from = contacts[drafted.from_name]
      to = contacts[drafted.to_name]
      next if from.nil? || to.nil?

      referral = Referral.find_or_initialize_by(referring_contact: from, referred_contact: to)
      referral.assign_attributes(condition: drafted.condition, enabled: true)
      referral.save!
      referral
    end
  end

  def build_share_rules(contacts)
    documents = Document.where(case_study_id: @case_study.id).index_by(&:file_name)

    @draft.share_rules.filter_map do |drafted|
      contact = contacts[drafted.contact_name]
      document = documents[drafted.file_name]
      next if contact.nil? || document.nil?

      rule = ShareRule.find_or_initialize_by(contact: contact, document: document)
      rule.assign_attributes(condition: drafted.condition)
      rule.save!
      rule
    end
  end
end
