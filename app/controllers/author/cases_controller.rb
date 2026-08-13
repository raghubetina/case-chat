module Author
  class CasesController < BaseController
    # As on the student side, the switcher is the list. With cases you land in
    # one; without any, this is the only authoring screen that has no shell.
    def index
      first = authored_cases.first
      redirect_to edit_author_case_path(first) if first
    end

    # Drawn inside the shell of whichever case you were last in, the way the
    # switcher implies — you are adding a case to a set, not leaving the app.
    def new
      authorize! CaseStudy, to: :new?
      @case_study = authored_cases.first
      @new_case = CaseStudy.new(author: current_user, join_code: suggested_code)
    end

    def create
      @new_case = CaseStudy.new(case_params.merge(author: current_user))
      authorize! @new_case, to: :create?

      if @new_case.save
        redirect_to edit_author_case_path(@new_case), notice: t("author.cases.created")
      else
        # @case_study is the shell's case, not the one being created.
        @case_study = authored_cases.first
        render :new, status: :unprocessable_content
      end
    end

    def edit
      @case_study = authored_case!
      load_authoring_state
    end

    # Authoring search is over the material the author writes: who is in the
    # cast, what they are told to be, and the files they can hand over.
    def search
      @case_study = authored_case!
      @query = params[:q].to_s.strip
      return if @query.blank?

      like = "%#{Contact.sanitize_sql_like(@query)}%"
      @contact_hits = Contact
        .where(case_study_id: @case_study.id)
        .where("full_name ILIKE :q OR role_title ILIKE :q OR description ILIKE :q OR system_prompt ILIKE :q", q: like)
        .order(:full_name)
        .limit(20)

      @document_hits = Document
        .where(case_study_id: @case_study.id)
        .where("file_name ILIKE :q OR description ILIKE :q", q: like)
        .order(:file_name)
        .limit(20)
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
