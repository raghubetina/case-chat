# What this case has spent, per stakeholder.
#
# Rehearsals and students' replies are counted apart because they answer two
# different questions: what the author burned writing the case, and what a
# cohort burns running it. Folding them together would forecast a student run
# at the cost of however many times the author rehearsed. They are still both
# shown, and both in the total, because the total has to reconcile with the
# provider's invoice or nobody trusts the screen twice.
#
# A rehearsal is a ModelCall with no message; a student's reply has one.
class ModelUsageReport
  Totals = Data.define(:calls, :input, :output, :cache_read, :cache_write) do
    def self.zero = new(calls: 0, input: 0, output: 0, cache_read: 0, cache_write: 0)

    def tokens = input + output

    def any? = calls.positive?

    # What the briefing cache bought, across a bucket rather than one call.
    def cache_hit_rate = input.zero? ? 0.0 : cache_read.fdiv(input)

    def +(other)
      Totals.new(
        calls: calls + other.calls, input: input + other.input, output: output + other.output,
        cache_read: cache_read + other.cache_read, cache_write: cache_write + other.cache_write
      )
    end
  end

  Row = Data.define(:contact, :models, :replies, :rehearsals, :cost) do
    def total = replies + rehearsals

    def priced? = !cost.nil?
  end

  def initialize(case_study)
    @case_study = case_study
  end

  def rows
    @rows ||= contacts.filter_map { |contact|
      mine = buckets.select { |bucket| bucket.contact_id == contact.id }
      next if mine.empty?

      Row.new(
        contact: contact,
        models: mine.map(&:model).uniq.sort,
        replies: sum_of(mine.reject(&:rehearsal)),
        rehearsals: sum_of(mine.select(&:rehearsal)),
        cost: cost_for(mine)
      )
    }.sort_by { |row| -row.total.tokens }
  end

  def reply_totals = @reply_totals ||= rows.map(&:replies).sum(Totals.zero)

  def rehearsal_totals = @rehearsal_totals ||= rows.map(&:rehearsals).sum(Totals.zero)

  def grand_totals = reply_totals + rehearsal_totals

  # nil when any model in the case has no price, rather than a partial sum
  # wearing the word "total".
  def cost
    return nil if rows.empty? || rows.any? { |row| row.cost.nil? }

    rows.sum(&:cost)
  end

  # Runs rather than students: a restart is a second run and a second bill.
  def run_count = @run_count ||= Enrollment.where(case_study_id: @case_study.id).count

  def tokens_per_run = run_count.zero? ? nil : reply_totals.tokens / run_count

  def any_calls? = rows.any?

  # Per student, per thread, per cohort -- the three questions an author asks
  # about cost. Per stakeholder answers a fourth, milder one, and stays for the
  # rehearsals, which have no student or thread to belong to.
  StudentRow = Data.define(:user, :runs, :threads, :totals, :cost) do
    def priced? = !cost.nil?
  end

  ThreadRow = Data.define(:conversation_id, :user, :contact, :totals, :cost) do
    def priced? = !cost.nil?
  end

  def student_rows
    @student_rows ||= student_buckets
      .group_by(&:user_id)
      .map { |user_id, mine|
        StudentRow.new(
          user: users[user_id],
          runs: mine.map(&:enrollment_id).uniq.size,
          threads: mine.map(&:conversation_id).uniq.size,
          totals: sum_of(mine),
          cost: cost_for(mine)
        )
      }
      .sort_by { |row| -row.totals.tokens }
  end

  def thread_rows
    @thread_rows ||= student_buckets
      .group_by(&:conversation_id)
      .map { |conversation_id, mine|
        first = mine.first
        ThreadRow.new(
          conversation_id: conversation_id,
          user: users[first.user_id],
          contact: contacts_by_id[first.contact_id],
          totals: sum_of(mine),
          cost: cost_for(mine)
        )
      }
      .sort_by { |row| -row.totals.tokens }
  end

  # The author's own test drives. Keyed by stakeholder because a rehearsal has
  # no student and no thread -- it is the one place per-stakeholder is the only
  # answer available, and the useful one.
  def rehearsal_rows
    @rehearsal_rows ||= rows.select { |row| row.rehearsals.any? }
      .sort_by { |row| -row.rehearsals.tokens }
  end

  private

  Bucket = Data.define(:contact_id, :model, :rehearsal, :totals, :cost)

  def contacts
    @contacts ||= Contact.where(case_study_id: @case_study.id).order(:full_name).to_a
  end

  def sum_of(buckets) = buckets.map(&:totals).sum(Totals.zero)

  # Each call carries the rate it was billed at, so cost is summed row by row in
  # the database rather than reconstructed here from a rate that may since have
  # moved. That also keeps this one grouped query: no rate in the grouping key,
  # no bucket per price change.
  COST = <<~SQL.squish
    SUM(
      (GREATEST(input_tokens - cache_read_tokens, 0) * input_price
        + cache_read_tokens * COALESCE(cache_read_price, 0)
        + output_tokens * output_price) / 1000000.0
    )
  SQL

  # One row per stakeholder, model and kind. A case is bounded by its cast
  # times the catalogue, so this is tens of rows at worst and the rest folds in
  # Ruby. The subquery keys on contact_id because model_calls has no case, and
  # nothing here walks an association, so strict loading has nothing to refuse.
  def buckets
    @buckets ||= ModelCall
      .where(contact_id: Contact.where(case_study_id: @case_study.id).select(:id))
      .group(:contact_id, :model, Arel.sql("message_id IS NULL"))
      .pluck(Arel.sql(<<~SQL.squish))
        contact_id, model, (message_id IS NULL),
        COUNT(*), SUM(input_tokens), SUM(output_tokens),
        SUM(cache_read_tokens), SUM(cache_write_tokens),
        #{COST}, BOOL_OR(input_price IS NULL OR output_price IS NULL)
      SQL
      .map do |contact_id, model, rehearsal, calls, input, output, cache_read, cache_write, cost, unpriced|
        Bucket.new(
          contact_id: contact_id, model: model, rehearsal: rehearsal,
          # A bucket holding one unpriced call reports nothing rather than a
          # partial sum wearing the word "total".
          cost: unpriced ? nil : cost&.to_f,
          totals: Totals.new(calls: calls, input: input, output: output,
            cache_read: cache_read, cache_write: cache_write)
        )
      end
  end

  def cost_for(buckets_for_row)
    costs = buckets_for_row.map(&:cost)
    costs.any?(&:nil?) ? nil : costs.sum
  end

  StudentBucket = Data.define(:user_id, :enrollment_id, :conversation_id, :contact_id, :totals, :cost)

  def users
    @users ||= User.where(id: student_buckets.map(&:user_id).uniq).index_by(&:id)
  end

  def contacts_by_id = @contacts_by_id ||= contacts.index_by(&:id)

  # Only calls carrying a message: a rehearsal has no message, so no thread and
  # no student to join to. One query at the finest grain the data supports --
  # a conversation -- and the student level folds up from it in Ruby rather than
  # costing a second trip.
  #
  # message_id is nullified when a message is deleted, so a call whose message
  # is gone drops out of these two groupings while remaining in the case total.
  # That is the honest behaviour: its student is genuinely no longer known.
  def student_buckets
    @student_buckets ||= ModelCall
      .where(contact_id: Contact.where(case_study_id: @case_study.id).select(:id))
      .where.not(message_id: nil)
      .joins("JOIN messages ON messages.id = model_calls.message_id")
      .joins("JOIN conversations ON conversations.id = messages.conversation_id")
      .joins("JOIN enrollments ON enrollments.id = conversations.enrollment_id")
      .group("enrollments.user_id", "enrollments.id", "conversations.id", "model_calls.contact_id")
      .pluck(Arel.sql(<<~SQL.squish))
        enrollments.user_id, enrollments.id, conversations.id, model_calls.contact_id,
        COUNT(*), SUM(input_tokens), SUM(output_tokens),
        SUM(cache_read_tokens), SUM(cache_write_tokens),
        #{COST}, BOOL_OR(input_price IS NULL OR output_price IS NULL)
      SQL
      .map do |user_id, enrollment_id, conversation_id, contact_id, calls, input, output, cache_read, cache_write, cost, unpriced|
        StudentBucket.new(
          user_id: user_id, enrollment_id: enrollment_id,
          conversation_id: conversation_id, contact_id: contact_id,
          cost: unpriced ? nil : cost&.to_f,
          totals: Totals.new(calls: calls, input: input, output: output,
            cache_read: cache_read, cache_write: cache_write)
        )
      end
  end
end
