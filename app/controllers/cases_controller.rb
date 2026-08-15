# The student's front door, and the panes of the workspace that are about the
# case rather than a conversation. Every action but #index and the two mutations
# renders inside the shell.
class CasesController < ApplicationController
  include CaseWorkspace

  before_action :authenticate
  before_action :load_case, only: %i[show background assignment files collected search]

  # There is no case list any more: the sidebar's switcher is the list. If you
  # are in a case, this drops you into the one you were most recently given; if
  # you are not, it is the only screen in the student app with no shell, because
  # there is no case to draw one around.
  def index
    newest = Enrollment.where(user_id: current_user.id).newest_first.first
    redirect_to case_path(newest.case_study_id) if newest
  end

  # Joining is a pane when you already have a case to keep the shell around,
  # and a bare page when this is your first.
  def new_join
    current = Enrollment.includes(case_study: :author).where(user_id: current_user.id).newest_first.first
    load_workspace(current) if current
  end

  # The directory pane: everyone this run has met.
  def show
  end

  def background
  end

  def assignment
  end

  def files
  end

  def collected
  end

  # Search runs over what this run can actually see — messages you have
  # exchanged and files you hold — never the whole case.
  def search
    @query = params[:q].to_s.strip
    return if @query.blank?

    @message_hits = Message
      .where(conversation_id: @enrollment.conversations.select(:id))
      .where("body ILIKE ?", "%#{Message.sanitize_sql_like(@query)}%")
      .includes(conversation: :contact)
      .order(sent_at: :desc)
      .limit(20)

    @document_hits = visible_documents
      .where("file_name ILIKE :q OR description ILIKE :q", q: "%#{Document.sanitize_sql_like(@query)}%")
      .order(file_name: :asc)
      .limit(20)
  end

  # Students join with the code the instructor posts alongside the assignment.
  def join
    case_study = CaseStudy.find_by_join_code(params[:join_code])

    if case_study.nil?
      redirect_to new_join_cases_path, alert: t("cases.join.unknown_code")
      return
    end

    existing = Enrollment.where(user_id: current_user.id, case_study_id: case_study.id).newest_first.first
    if existing
      redirect_to case_path(case_study), notice: t("cases.join.already_enrolled")
      return
    end

    enrollment = Enrollment.new(user: current_user, case_study: case_study)
    authorize! enrollment, to: :create?
    enrollment.save!

    redirect_to case_path(case_study), notice: t("cases.join.joined", title: case_study.title)
  end

  # A fresh run: new enrollment, empty directory, nothing met. Earlier runs stay
  # readable as history.
  def restart
    case_study = CaseStudy.find(params[:id])
    authorize! case_study, to: :show?

    enrollment = Enrollment.new(user: current_user, case_study: case_study)
    authorize! enrollment, to: :create?
    enrollment.save!

    redirect_to case_path(case_study), notice: t("cases.restart.started")
  end

  private

  # Somebody with no run here is not an error, they are somebody who has not
  # joined yet -- most often the author, who reaches this from "Preview as
  # student" and holds the code they need. Joining stays an explicit act: an
  # author who is enrolled behind their own back turns up in their own cohort.
  def load_case
    enrollment = current_run
    return redirect_to(new_join_cases_path, alert: t("cases.not_enrolled")) if enrollment.nil?

    authorize! enrollment.case_study, to: :show?
    load_workspace(enrollment)
  end

  # `run` selects an older enrollment; without it you get the live one. A run id
  # that names nothing is still a 404 -- that is a bad link, not a missing join.
  def current_run
    runs = Enrollment.where(user_id: current_user.id, case_study_id: params[:id]).newest_first
    enrollment = params[:run].present? ? runs.find(params[:run]) : runs.first
    return nil if enrollment.nil?

    Enrollment.includes(case_study: :author).find(enrollment.id)
  end
end
