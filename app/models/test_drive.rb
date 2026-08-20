# An author talking to a stakeholder they are writing, to find out whether the
# prompt they just saved actually behaves.
#
# A drive is kept, and Reset opens a new one rather than erasing this one. That
# is the point: ask the same question of Opus at high and of Sol at medium and
# the two transcripts sit side by side afterwards, each with its own cost.
#
# It is still not domain data. A drive creates no Enrollment, no Conversation,
# no Message, and applies no Introduction or DocumentShare -- an author
# rehearsing their own case must not appear in their own cohort report, and a
# student opening a thread must not find someone else's rehearsal in it. These
# are separate tables for exactly that reason: nothing that reads conversations
# or messages can reach them by accident.
#
# What it does share with a real conversation is the briefing. ContactBriefing
# composes exactly what a student's reply is generated from, so a rehearsal that
# used anything else would be testing something no student will meet.
# == Schema Information
#
# Table name: test_drives
#
#  id                    :uuid             not null, primary key
#  briefing_text         :text
#  knows_case_background :boolean
#  role_title            :string
#  system_prompt         :text
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  author_id             :uuid             not null
#  contact_id            :uuid             not null
#
# Indexes
#
#  index_test_drives_on_author_id                                (author_id)
#  index_test_drives_on_contact_id_and_author_id_and_created_at  (contact_id,author_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (author_id => users.id) ON DELETE => cascade
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#
class TestDrive < ApplicationRecord
  belongs_to :contact, class_name: "Contact", optional: false
  belongs_to :author, class_name: "User", optional: false
  has_many :turns, -> { order(:created_at) }, class_name: "TestDriveTurn", dependent: :destroy
  has_many :model_calls, class_name: "ModelCall", dependent: :nullify

  scope :newest_first, -> { order(created_at: :desc) }

  # The drive an author is currently in for this stakeholder, opening one if
  # they have never rehearsed it or have just reset.
  # Always preloaded. strict_loading is on by default and a drive is never used
  # without its contact and its turns -- the briefing wants one and the history
  # wants the other -- so the finder loads them rather than each caller
  # discovering the guard. Creating costs a second query, on the one path where
  # there is nothing to load yet.
  def self.current(author, contact)
    mine(author, contact).first || begin
      create!(author: author, contact: contact, **snapshot_of(contact))
      mine(author, contact).first
    end
  end

  def self.open_new(author, contact)
    create!(author: author, contact: contact, **snapshot_of(contact))
    mine(author, contact).first
  end

  # Written once, when the drive opens, and never updated. Reading two runs
  # side by side, "why did these differ" is as often the prompt as the model,
  # and an edit between runs is invisible unless the run recorded what it used.
  #
  # briefing_text is the whole thing, not the author's field. ContactBriefing
  # composes the case background, the persona, the referral and share sections
  # and the answering rules; the author's own system_prompt was under half of
  # what the model actually read. The individual fields are kept alongside it
  # because they are what the editor edits, and naming which one moved is more
  # use than pointing at a diff of four thousand characters.
  def self.snapshot_of(contact)
    {
      briefing_text: ContactBriefing.new(contact).system_text,
      system_prompt: contact.system_prompt,
      role_title: contact.role_title,
      knows_case_background: contact.knows_case_background
    }
  end

  # True when the prompt has moved since this run, so the board can say so
  # rather than letting a prompt change read as a model difference. Takes the
  # person rather than reaching through the association: the caller is rendering
  # one contact's drives and already holds it.
  #
  # Compared against the composed briefing where there is one, because the
  # levers an author pulls are not all on the person. A referral's condition
  # lives on the edge between two people and the background lives on the case,
  # and editing either changes what the model reads while every field on this
  # contact stays put -- so the three-field comparison below called that
  # unchanged.
  def stale?(current)
    return briefing_text != ContactBriefing.new(current).system_text if briefing_text.present?
    return false if system_prompt.nil?

    system_prompt != current.system_prompt ||
      role_title != current.role_title ||
      knows_case_background != current.knows_case_background
  end

  def self.mine(author, contact)
    where(author_id: author.id, contact_id: contact.id)
      .newest_first.includes(:contact, :author, :turns)
  end

  def ask(text) = turns.create!(from_contact: false, body: text.to_s.strip)

  def answer(reply)
    turns.create!(
      from_contact: true,
      body: ContactReply.spoken_body(reply),
      introduced_contact_ids: reply.introduced_contact_ids,
      shared_document_ids: reply.shared_document_ids
    )
  end

  # The responder wants Message-shaped objects. These are never saved; building
  # them unsaved is what keeps a rehearsal out of any transcript.
  def history
    turns.map do |turn|
      Message.new(body: turn.body, from_contact: turn.from_contact, sent_at: turn.created_at)
    end
  end

  def briefing = ContactBriefing.new(contact)

  # Broadcasts are scoped to the author as well as the contact: two authors on
  # one case would otherwise watch each other's rehearsals.
  def stream_name = [contact, author, :test_drive]

  # What answered, taken from the calls themselves rather than stored here: an
  # author can change the model mid-drive, and the calls are what actually ran.
  def models_used = model_calls.distinct.pluck(:model, :effort)
end
