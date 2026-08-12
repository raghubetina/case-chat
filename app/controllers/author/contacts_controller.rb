module Author
  # The cast editor: who is in the case, what they know, and what they withhold.
  class ContactsController < BaseController
    def new
      @case_study = authored_case!
      authorize! Contact, to: :new?
      @contact = Contact.new(case_study: @case_study)
    end

    def create
      @case_study = authored_case!
      @contact = Contact.new(contact_params.merge(case_study: @case_study))
      authorize! @contact, to: :create?

      if @contact.save
        redirect_to edit_author_case_contact_path(@case_study, @contact), notice: t("author.contacts.created")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      @case_study = authored_case!
      @contact = Contact.where(case_study_id: @case_study.id).find(params[:id])
      load_editor_state
    end

    def update
      @case_study = authored_case!
      @contact = Contact.where(case_study_id: @case_study.id).find(params[:id])
      authorize! @contact, to: :update?

      if @contact.update(contact_params)
        redirect_to edit_author_case_contact_path(@case_study, @contact), notice: t("author.contacts.saved")
      else
        load_editor_state
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @case_study = authored_case!
      contact = Contact.where(case_study_id: @case_study.id).find(params[:id])
      authorize! contact, to: :destroy?
      contact.destroy!

      redirect_to edit_author_case_path(@case_study), notice: t("author.contacts.removed")
    end

    private

    def load_editor_state
      # Everyone else in this case is a possible handoff; you cannot refer
      # someone to themselves.
      @candidates = Contact.where(case_study_id: @case_study.id).where.not(id: @contact.id).order(:full_name)
      @referrals = @contact.outgoing_referrals.includes(:referred_contact).to_a
      @referred_ids = @referrals.map(&:referred_contact_id).to_set
      @share_rules = @contact.share_rules.includes(:document).to_a
      @documents = Document.where(case_study_id: @case_study.id).order(:file_name)
      @introducers = CaseReachability.new(@case_study).introducers_for(@contact)
    end

    def contact_params
      params.expect(contact: %i[full_name role_title description system_prompt in_starting_directory])
    end
  end
end
