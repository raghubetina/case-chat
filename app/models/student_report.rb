# One student's work on one case, gathered so it can be read rather than
# counted.
#
# CohortReport answers "how did the class do". This answers the question an
# author asks next, standing in front of a row of that table: what did this
# person actually say. So it carries transcripts, not totals.
#
# A student can restart a case, and each run is its own Enrollment with its own
# threads. Runs are kept apart rather than pooled: the same contact asked the
# same question in run one and in run three is the interesting comparison, and
# merging them would destroy it.
class StudentReport
  # Not Thread — that name is taken by something far more important, and this
  # class would shadow it for every line inside StudentReport.
  Transcript = Data.define(:conversation, :messages) do
    def contact = conversation.contact
  end

  Run = Data.define(:enrollment, :transcripts) do
    def run_number = enrollment.run_number
    def started_at = enrollment.started_at
    def asked = transcripts.sum { |t| t.messages.count { |m| !m.from_contact? } }
    def contacts_met = transcripts.size
  end

  attr_reader :user, :case_study

  def initialize(case_study, user)
    @case_study = case_study
    @user = user
  end

  # Newest run first, matching the test drive board: the thing you just watched
  # happen is the thing you came to look at.
  def runs
    @runs ||= enrollments.map { |enrollment|
      Run.new(enrollment: enrollment, transcripts: transcripts_for(enrollment))
    }
  end

  def any_messages? = runs.any? { |run| run.asked.positive? }

  def last_active_at = enrollments.filter_map(&:last_active_at).max

  private

  def enrollments
    @enrollments ||= Enrollment
      .where(case_study_id: @case_study.id, user_id: @user.id)
      .newest_first.to_a
  end

  def transcripts_for(enrollment)
    conversations.fetch(enrollment.id, []).map { |conversation|
      Transcript.new(conversation: conversation, messages: messages.fetch(conversation.id, []))
    }
  end

  # Every conversation across every run in one query, then grouped in Ruby.
  def conversations
    @conversations ||= Conversation
      .where(enrollment_id: enrollments.map(&:id))
      .includes(:contact)
      .order(:created_at)
      .group_by(&:enrollment_id)
  end

  # strict_loading is on and threads/_message reaches for the contact behind
  # each introduction and the document behind each share, so both are named
  # here rather than discovered one N+1 at a time.
  def messages
    @messages ||= Message
      .where(conversation_id: conversations.values.flatten.map(&:id))
      .includes({conversation: :contact}, {introductions: :contact}, {document_shares: :document})
      .order(:sent_at)
      .group_by(&:conversation_id)
  end
end
