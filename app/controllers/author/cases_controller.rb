module Author
  class CasesController < BaseController
    def index
      @cases = authorized_scope(CaseStudy.all, as: :authored).order(:title)
    end

    def new
      authorize! CaseStudy, to: :new?
      @case_study = CaseStudy.new(author: current_user, join_code: suggested_code)
    end

    def create
      @case_study = CaseStudy.new(case_params.merge(author: current_user))
      authorize! @case_study, to: :create?

      if @case_study.save
        redirect_to edit_author_case_path(@case_study), notice: t("author.cases.created")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      @case_study = authored_case!
      load_authoring_state
    end

    def update
      @case_study = authored_case!

      if @case_study.update(case_params)
        redirect_to edit_author_case_path(@case_study), notice: t("author.cases.saved")
      else
        load_authoring_state
        render :edit, status: :unprocessable_content
      end
    end

    # Publishing is the moment students can see any of this, so it refuses
    # while anyone in the cast is unreachable.
    def publish
      @case_study = authored_case!
      result = CaseReachability.new(@case_study).call

      if result.complete? && cast_for(@case_study).any?
        @case_study.update!(published: true)
        redirect_to edit_author_case_path(@case_study), notice: t("author.cases.published")
      else
        redirect_to edit_author_case_path(@case_study), alert: publish_blocker(result)
      end
    end

    private

    def cast_for(case_study)
      Contact.where(case_study_id: case_study.id)
    end

    def load_authoring_state
      @contacts = cast_for(@case_study).order(in_starting_directory: :desc, full_name: :asc)
      @documents = Document.where(case_study_id: @case_study.id).order(given_at_start: :desc, file_name: :asc)
      @reachability = CaseReachability.new(@case_study).call
      @introducers = Referral
        .includes(:referring_contact)
        .where(referred_contact_id: cast_for(@case_study).select(:id), enabled: true)
        .group_by(&:referred_contact_id)
    end

    def publish_blocker(result)
      return t("author.cases.publish_blocked_empty") if cast_for(@case_study).empty?

      t("author.cases.publish_blocked", names: result.unreachable.map(&:full_name).to_sentence)
    end

    def case_params
      params.expect(case_study: %i[title course background assignment join_code due_at published])
    end

    def suggested_code
      "#{SecureRandom.alphanumeric(5).upcase}-#{SecureRandom.random_number(90) + 10}"
    end
  end
end
