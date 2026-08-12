# What a cohort actually did with a case.
#
# Every figure here is read off the transcript rather than tracked separately:
# an Introduction row means a student genuinely earned that contact, a
# DocumentShare row means a contact genuinely handed something over. That is
# the payoff for making those structured records instead of parsing them back
# out of prose later.
#
# The interesting column is reach: which contacts the cohort found. A person
# almost nobody reaches is either buried behind a condition that never fires,
# or holds something the case never gives students a reason to ask about.
class CohortReport
  Student = Data.define(:user, :run_count, :contacts_met, :messages_sent, :documents_earned, :last_active_at)
  Reach = Data.define(:contact, :student_count, :share)

  def initialize(case_study)
    @case_study = case_study
  end

  def students
    @students ||= begin
      rows = enrollments.group_by(&:user_id)

      rows.map { |user_id, runs|
        Student.new(
          user: users.fetch(user_id),
          run_count: runs.size,
          contacts_met: distinct_contacts_met(runs),
          messages_sent: runs.sum { |run| messages_by_enrollment.fetch(run.id, 0) },
          documents_earned: distinct_documents_earned(runs),
          last_active_at: runs.filter_map(&:last_active_at).max
        )
      }.sort_by { |student| [-student.contacts_met, student.user.full_name] }
    end
  end

  def reach
    total = students.size
    counts = introductions_by_contact

    contacts.map { |contact|
      met = counts.fetch(contact.id, 0)
      # Everyone in the starting directory is met by definition, so counting
      # only Introduction rows would report them at zero.
      met = total if contact.in_starting_directory? && total.positive?
      Reach.new(contact: contact, student_count: met, share: total.zero? ? 0.0 : met.to_f / total)
    }.sort_by { |row| -row.student_count }
  end

  def started_count = students.count { |student| student.messages_sent.positive? }

  def enrolled_count = students.size

  def median_contacts_met = median(students.map(&:contacts_met))

  def median_messages_sent = median(students.map(&:messages_sent))

  def median_documents_earned = median(students.map(&:documents_earned))

  def contact_count = contacts.size

  def document_count = Document.where(case_study_id: @case_study.id).count

  private

  def contacts
    @contacts ||= Contact.where(case_study_id: @case_study.id).order(:full_name).to_a
  end

  def enrollments
    @enrollments ||= Enrollment.where(case_study_id: @case_study.id).to_a
  end

  def users
    @users ||= User.where(id: enrollments.map(&:user_id)).index_by(&:id)
  end

  def enrollment_ids = @enrollment_ids ||= enrollments.map(&:id)

  def conversation_ids_by_enrollment
    @conversation_ids_by_enrollment ||= Conversation
      .where(enrollment_id: enrollment_ids)
      .pluck(:enrollment_id, :id)
      .group_by(&:first)
      .transform_values { |pairs| pairs.map(&:last) }
  end

  # Only the student's own messages count as effort; the contact's replies are
  # a function of them.
  def messages_by_enrollment
    @messages_by_enrollment ||= begin
      counts = Message
        .where(conversation_id: conversation_ids_by_enrollment.values.flatten, from_contact: false)
        .group(:conversation_id)
        .count

      conversation_ids_by_enrollment.transform_values do |ids|
        ids.sum { |id| counts.fetch(id, 0) }
      end
    end
  end

  def introductions_by_enrollment
    @introductions_by_enrollment ||= Introduction
      .where(enrollment_id: enrollment_ids)
      .pluck(:enrollment_id, :contact_id)
      .group_by(&:first)
      .transform_values { |pairs| pairs.map(&:last) }
  end

  def introductions_by_contact
    @introductions_by_contact ||= Introduction
      .where(enrollment_id: enrollment_ids)
      .distinct
      .pluck(:contact_id, :enrollment_id)
      .group_by(&:first)
      .transform_values { |pairs| pairs.map(&:last).to_set.size }
  end

  def starting_contact_ids
    @starting_contact_ids ||= contacts.select(&:in_starting_directory?).map(&:id)
  end

  # Across runs, a student "met" someone if any run met them. Starting-directory
  # contacts count for anyone who has a run at all.
  def distinct_contacts_met(runs)
    met = runs.flat_map { |run| introductions_by_enrollment.fetch(run.id, []) }
    (met + starting_contact_ids).uniq.size
  end

  def distinct_documents_earned(runs)
    conversation_ids = runs.flat_map { |run| conversation_ids_by_enrollment.fetch(run.id, []) }
    return 0 if conversation_ids.empty?

    DocumentShare
      .where(message_id: Message.where(conversation_id: conversation_ids).select(:id))
      .distinct
      .count(:document_id)
  end

  def median(values)
    return 0 if values.empty?

    sorted = values.sort
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : ((sorted[middle - 1] + sorted[middle]) / 2.0).round
  end
end
