# What the author's shell needs to draw itself: the case being built, its cast,
# and whether anyone in that cast is stranded.
#
# The mirror of CaseWorkspace on the student side. Every authoring pane renders
# the same sidebar, so every authoring pane loads the same context; the
# relations stay lazy so a pane that does not need one never runs its query.
module AuthoringWorkspace
  extend ActiveSupport::Concern

  included do
    helper_method :authored_cases, :authoring_cast, :authoring_documents,
      :authoring_enrollment_count, :unreachable_ids
  end

  private

  def authored_cases
    @authored_cases ||= authorized_scope(CaseStudy.all, as: :authored).order(:title)
  end

  def authoring_cast
    @authoring_cast ||= Contact
      .where(case_study_id: @case_study.id)
      .order(in_starting_directory: :desc, full_name: :asc)
  end

  def authoring_documents
    @authoring_documents ||= Document
      .where(case_study_id: @case_study.id)
      .order(given_at_start: :desc, file_name: :asc)
  end

  def authoring_enrollment_count
    @authoring_enrollment_count ||= Enrollment.where(case_study_id: @case_study.id).count
  end

  # The sidebar flags stranded contacts, so reachability is shell state rather
  # than something only the Setup pane knows.
  def reachability
    @reachability ||= CaseReachability.new(@case_study).call
  end

  def unreachable_ids
    @unreachable_ids ||= reachability.unreachable.map(&:id).to_set
  end
end
