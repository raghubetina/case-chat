module CaseDrafter
  # A deterministic draft, used in tests and in development without a key. It
  # exercises the same contract the real adapters do — a cast, a referral chain,
  # and a share rule — so the review-and-accept flow around it is genuinely
  # tested rather than stubbed past.
  class Fake
    def draft(documents:, hint: nil)
      names = documents.map(&:file_name)

      Draft.new(
        title: hint.presence || "Drafted case",
        course: "Drafted course",
        background: "Drafted from #{names.size} document#{"s" unless names.size == 1}.",
        assignment: "Bring a recommendation and say what you had to assume.",
        contacts: [
          DraftedContact.new(
            full_name: "Dana Whitfield", role_title: "Chief Financial Officer",
            description: "Owns the numbers.",
            system_prompt: "You are Dana Whitfield. Speak in numbers. Refer the student onward when pressed on operations.",
            in_starting_directory: true
          ),
          DraftedContact.new(
            full_name: "Priya Raghunathan", role_title: "Plant Manager",
            description: "Runs the floor.",
            system_prompt: "You are Priya Raghunathan. You know what actually happens on the line.",
            in_starting_directory: false
          )
        ],
        referrals: [
          DraftedReferral.new(
            from_name: "Dana Whitfield", to_name: "Priya Raghunathan",
            condition: "When the student pushes on causes Dana cannot see."
          )
        ],
        share_rules: names.first ? [
          DraftedShareRule.new(
            contact_name: "Dana Whitfield", file_name: names.first,
            condition: "Once the student asks to see the numbers."
          )
        ] : [],
        notes: ["Drafted offline. Review every system prompt before publishing."]
      )
    end
  end
end
