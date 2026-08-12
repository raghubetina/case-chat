module CaseDrafter
  # Turns a model's JSON into the Draft value objects, dropping anything
  # structurally unusable rather than letting a malformed row reach the review
  # screen as a half-filled form.
  module Parser
    def self.call(payload)
      contacts = Array(payload["contacts"]).filter_map { |row| contact(row) }
      names = contacts.map(&:full_name).to_set

      Draft.new(
        title: payload["title"].to_s.presence || "Untitled case",
        course: payload["course"].presence,
        background: payload["background"].presence,
        assignment: payload["assignment"].presence,
        contacts: contacts,
        # A referral naming someone who is not in the cast cannot be built.
        referrals: Array(payload["referrals"]).filter_map { |row| referral(row, names) },
        share_rules: Array(payload["share_rules"]).filter_map { |row| share_rule(row, names) },
        notes: Array(payload["notes"]).map(&:to_s)
      )
    end

    def self.contact(row)
      return nil if row["full_name"].blank? || row["system_prompt"].blank?

      DraftedContact.new(
        full_name: row["full_name"].to_s.strip,
        role_title: row["role_title"].to_s.strip.presence || "Contact",
        description: row["description"].to_s.strip.presence,
        system_prompt: row["system_prompt"].to_s.strip,
        in_starting_directory: !!row["in_starting_directory"]
      )
    end

    def self.referral(row, names)
      return nil unless names.include?(row["from_name"]) && names.include?(row["to_name"])
      return nil if row["from_name"] == row["to_name"] || row["condition"].blank?

      DraftedReferral.new(
        from_name: row["from_name"], to_name: row["to_name"], condition: row["condition"].to_s.strip
      )
    end

    def self.share_rule(row, names)
      return nil unless names.include?(row["contact_name"])
      return nil if row["file_name"].blank? || row["condition"].blank?

      DraftedShareRule.new(
        contact_name: row["contact_name"], file_name: row["file_name"], condition: row["condition"].to_s.strip
      )
    end
  end
end
