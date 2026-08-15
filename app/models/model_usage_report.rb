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

  private

  Bucket = Data.define(:contact_id, :model, :rehearsal, :totals)

  def contacts
    @contacts ||= Contact.where(case_study_id: @case_study.id).order(:full_name).to_a
  end

  def sum_of(buckets) = buckets.map(&:totals).sum(Totals.zero)

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
        SUM(cache_read_tokens), SUM(cache_write_tokens)
      SQL
      .map do |contact_id, model, rehearsal, calls, input, output, cache_read, cache_write|
        Bucket.new(
          contact_id: contact_id, model: model, rehearsal: rehearsal,
          totals: Totals.new(calls: calls, input: input, output: output,
            cache_read: cache_read, cache_write: cache_write)
        )
      end
  end

  # Priced per model and then summed: rates differ per model, so a stakeholder
  # whose model changed mid-case cannot be priced in one call.
  def cost_for(buckets_for_row)
    per_model = buckets_for_row.group_by(&:model).map do |model, group|
      totals = sum_of(group)
      ModelCatalogue.cost(
        model: model,
        input_tokens: totals.input,
        output_tokens: totals.output,
        cache_read_tokens: totals.cache_read
      )
    end

    per_model.any?(&:nil?) ? nil : per_model.sum
  end
end
