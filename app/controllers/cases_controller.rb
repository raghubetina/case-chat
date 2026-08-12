# The student's front door: the cases you are working, and the code that gets
# you into a new one.
class CasesController < ApplicationController
  before_action :authenticate

  def index
    @enrollments = authorized_scope(Enrollment.all)
      .where(user_id: current_user.id)
      .includes(:case_study)
      .newest_first
  end

  def show
    @enrollment = current_run!
    @case_study = @enrollment.case_study
    authorize! @case_study, to: :show?

    @contacts = directory_for(@enrollment)
    @documents = earned_documents(@enrollment)
    @threads_by_contact = @enrollment.conversations.includes(:messages).index_by(&:contact_id)
  end

  # Students join with the code the instructor posts alongside the assignment.
  def join
    case_study = CaseStudy.find_by_join_code(params[:join_code])

    if case_study.nil?
      redirect_to cases_path, alert: t("cases.join.unknown_code")
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

  # `run` selects an older enrollment; without it you get the live one.
  def current_run!
    runs = Enrollment.where(user_id: current_user.id, case_study_id: params[:id]).newest_first
    enrollment = params[:run].present? ? runs.find(params[:run]) : runs.first
    raise ActiveRecord::RecordNotFound if enrollment.nil?

    Enrollment.includes(:case_study).find(enrollment.id)
  end

  # The directory is what this run has earned: everyone in the starting
  # directory, plus everyone introduced so far.
  def directory_for(enrollment)
    met_ids = Introduction.where(enrollment_id: enrollment.id).pluck(:contact_id)

    Contact
      .where(case_study_id: enrollment.case_study_id)
      .where(in_starting_directory: true).or(
        Contact.where(case_study_id: enrollment.case_study_id, id: met_ids)
      )
      .order(in_starting_directory: :desc, full_name: :asc)
  end

  def earned_documents(enrollment)
    shared_ids = DocumentShare
      .where(message_id: Message.where(conversation_id: enrollment.conversations.select(:id)).select(:id))
      .select(:document_id)

    Document
      .where(case_study_id: enrollment.case_study_id)
      .where(given_at_start: true).or(
        Document.where(case_study_id: enrollment.case_study_id, id: shared_ids)
      )
      .order(given_at_start: :desc, file_name: :asc)
  end
end
