module Author
  module Contacts
    # A referral is a directed edge with a cue: this contact may hand the
    # student to that one, when the condition is met.
    class ReferralsController < BaseController
      def create
        contact = authored_contact!
        referral = Referral.new(
          referring_contact: contact,
          referred_contact_id: params.require(:referral)[:referred_contact_id],
          condition: params.require(:referral)[:condition]
        )
        authorize! referral, to: :create?

        if referral.save
          redirect_back_to(contact, notice: t("author.referrals.added"))
        else
          redirect_back_to(contact, alert: referral.errors.full_messages.to_sentence)
        end
      end

      def destroy
        contact = authored_contact!
        referral = contact.outgoing_referrals.find(params[:id])
        authorize! referral, to: :destroy?
        referral.destroy!

        redirect_back_to(contact, notice: t("author.referrals.removed"))
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
