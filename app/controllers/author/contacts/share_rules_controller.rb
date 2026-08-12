module Author
  module Contacts
    # A share rule is what this contact will hand over, and what the student
    # has to have asked before they will.
    class ShareRulesController < BaseController
      def create
        contact = authored_contact!
        rule = ShareRule.new(
          contact: contact,
          document_id: params.require(:share_rule)[:document_id],
          condition: params.require(:share_rule)[:condition]
        )
        authorize! rule, to: :create?

        if rule.save
          redirect_back_to(contact, notice: t("author.share_rules.added"))
        else
          redirect_back_to(contact, alert: rule.errors.full_messages.to_sentence)
        end
      end

      def destroy
        contact = authored_contact!
        rule = contact.share_rules.find(params[:id])
        authorize! rule, to: :destroy?
        rule.destroy!

        redirect_back_to(contact, notice: t("author.share_rules.removed"))
      end

      private

      def authored_contact!
        contact = Contact.includes(:case_study).find(params[:contact_id])
        authorize! contact, to: :update?
        contact
      end

      def redirect_back_to(contact, **flash_args)
        redirect_to edit_author_case_contact_path(contact.case_study_id, contact), **flash_args
      end
    end
  end
end
