module Author
  module Contacts
    # Rehearsing a stakeholder from inside the editor.
    class TestDrivesController < Author::BaseController
      # A test drive costs a model call, and the button sits next to a textarea.
      # This is generous for someone iterating on a prompt and still bounded.
      rate_limit to: 30, within: 5.minutes,
        by: -> { current_user.id },
        with: :too_many_test_drives,
        name: "test_drive"

      def create
        drive = drive_for(params[:contact_id])
        question = params.require(:test_drive).permit(:body)[:body].to_s.strip

        if question.blank?
          return redirect_to edit_author_case_contact_path(@case_study, @contact),
            alert: t("author.test_drive.blank")
        end

        asked = drive.ask(question)
        TestDriveJob.perform_later(@contact.id, current_user.id)

        respond_to do |format|
          format.turbo_stream { render_asked(drive, asked) }
          format.html { redirect_to edit_author_case_contact_path(@case_study, @contact) }
        end
      end

      def destroy
        drive_for(params[:contact_id]).reset

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "test_drive", partial: "author/contacts/test_drive",
              locals: {contact: @contact, case_study: @case_study, drive: drive_for(params[:contact_id])}
            )
          end
          format.html { redirect_to edit_author_case_contact_path(@case_study, @contact) }
        end
      end

      private

      def drive_for(contact_id)
        @case_study = authored_case!
        @contact = Contact.includes(:case_study)
          .where(case_study_id: @case_study.id)
          .find(contact_id)
        authorize! @contact, to: :update?

        TestDrive.new(current_user, @contact)
      end

      def render_asked(drive, asked)
        render turbo_stream: [
          turbo_stream.remove("test_drive_empty"),
          turbo_stream.append("test_transcript", partial: "author/contacts/test_turn",
            locals: {turn: asked, contact: @contact}),
          turbo_stream.append("test_transcript", partial: "author/contacts/test_pending",
            locals: {contact: @contact, drive: drive}),
          turbo_stream.replace("test_composer", partial: "author/contacts/test_composer",
            locals: {contact: @contact, case_study: @case_study})
        ]
      end

      def too_many_test_drives
        redirect_to edit_author_case_contact_path(@case_study, @contact),
          alert: t("author.test_drive.too_many")
      end
    end
  end
end
