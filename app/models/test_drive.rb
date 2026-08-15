# An author talking to a stakeholder they are writing, to find out whether the
# prompt they just saved actually behaves.
#
# Nothing here is persisted as domain data. A test drive creates no Enrollment,
# no Conversation, no Message, and no Introduction or DocumentShare — if it did,
# an author trying out their own case would appear in their own cohort report,
# and a student opening that thread would find someone else's rehearsal in it.
# The transcript lives in the cache and expires on its own.
#
# What it does share with a real conversation is the briefing. ContactBriefing
# composes exactly what a student's reply is generated from, so a test that used
# anything else would be testing something the student will never meet.
class TestDrive
  EXPIRES_IN = 2.hours

  # A contact's answer may fire the introduce or share tool. Those are the
  # interesting events for an author — the condition either matched or it did
  # not — so they are carried alongside the text rather than being applied.
  Turn = Struct.new(:role, :text, :introduced_ids, :shared_ids) do
    def from_contact? = role.to_s == "contact"
  end

  attr_reader :author, :contact

  def initialize(author, contact)
    @author = author
    @contact = contact
  end

  def turns
    (Rails.cache.read(cache_key) || []).map { |attrs| Turn.new(**attrs) }
  end

  def ask(text)
    append(role: "student", text: text.to_s.strip)
  end

  def answer(reply)
    append(
      role: "contact",
      text: reply.text,
      introduced_ids: reply.introduced_contact_ids,
      shared_ids: reply.shared_document_ids
    )
  end

  def reset
    Rails.cache.delete(cache_key)
  end

  # The responder wants Message-shaped objects. These are never saved; building
  # them unsaved is what keeps a rehearsal out of the transcript.
  def history
    turns.map do |turn|
      Message.new(body: turn.text, from_contact: turn.from_contact?, sent_at: Time.current)
    end
  end

  def briefing = ContactBriefing.new(contact)

  # Broadcasts are scoped to the author as well as the contact: two authors on
  # one case would otherwise watch each other's rehearsals.
  def stream_name = [contact, author, :test_drive]

  def dom_id_for(suffix) = ActionView::RecordIdentifier.dom_id(contact, "test_#{suffix}")

  private

  def append(**attrs)
    turn = {role: nil, text: nil, introduced_ids: [], shared_ids: []}.merge(attrs)
    Rails.cache.write(cache_key, turns.map(&:to_h) + [turn], expires_in: EXPIRES_IN)
    Turn.new(**turn)
  end

  def cache_key = ["test_drive", author.id, contact.id].join("/")
end
