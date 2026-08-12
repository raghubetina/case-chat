# Can a student actually get to everyone in this case?
#
# This is the question structured Referral rows exist to answer. If referral
# logic lived only as prose inside each contact's system prompt, an author
# would have to read six prompts and reason about a graph in their head to
# notice that one person is unreachable — and a contact nobody can reach is a
# silent hole in the case: the student can never find them, so whatever they
# know never enters the analysis.
#
# The walk is a breadth-first search from the starting directory across enabled
# referrals. Disabled referrals are edges the author has switched off, so they
# do not count.
class CaseReachability
  Result = Data.define(:reachable, :unreachable, :starting) do
    def complete? = unreachable.empty?

    def orphan_count = unreachable.size
  end

  def initialize(case_study)
    @case_study = case_study
  end

  def call
    contacts = Contact.where(case_study_id: @case_study.id).to_a
    starting = contacts.select(&:in_starting_directory?)

    reachable_ids = walk(starting.map(&:id))

    Result.new(
      reachable: contacts.select { |contact| reachable_ids.include?(contact.id) },
      unreachable: contacts.reject { |contact| reachable_ids.include?(contact.id) },
      starting: starting
    )
  end

  # Who introduces this contact, and on what cue. Drives the "Introduced by N"
  # badge and tells an author how to fix an orphan.
  def introducers_for(contact)
    Referral
      .includes(:referring_contact)
      .where(referred_contact_id: contact.id, enabled: true)
      .map(&:referring_contact)
  end

  private

  def walk(seed_ids)
    seen = seed_ids.to_set
    frontier = seed_ids

    until frontier.empty?
      next_ids = Referral
        .where(referring_contact_id: frontier, enabled: true)
        .pluck(:referred_contact_id)
        .reject { |id| seen.include?(id) }

      seen.merge(next_ids)
      frontier = next_ids
    end

    seen
  end
end
