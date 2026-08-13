module CaseDrafter
  # Turns a model's JSON into the Draft value objects.
  #
  # Everything here treats the payload as untrusted. A schema is a request, not
  # a guarantee: a provider can return null where an object was asked for, a
  # scalar where a row was, a duplicate name, or a string longer than the column
  # it will land in. None of those may reach the review screen as a half-filled
  # form, and none may reach `accept` as a 500.
  module Parser
    # Long enough for any real value, short enough that nothing overflows the
    # column it is bound for. `title` matches the CaseStudy limit exactly.
    TITLE_LIMIT = 200
    NAME_LIMIT = 255
    TEXT_LIMIT = 20_000

    def self.call(payload, file_names: nil)
      payload = {} unless payload.is_a?(Hash)

      contacts = drafted_contacts(payload["contacts"])
      raise Error, "the draft proposed no usable contacts" if contacts.empty?

      names = contacts.map(&:full_name).to_set

      Draft.new(
        title: clamp(payload["title"], TITLE_LIMIT).presence || "Untitled case",
        course: clamp(payload["course"], NAME_LIMIT).presence,
        background: clamp(payload["background"], TEXT_LIMIT).presence,
        assignment: clamp(payload["assignment"], TEXT_LIMIT).presence,
        contacts: contacts,
        # A referral naming someone who is not in the cast cannot be built, and
        # the pair is the fact: two referrals between the same two people are
        # one row once imported, so only the first is reviewed.
        referrals: rows(payload["referrals"])
          .filter_map { |row| referral(row, names) }
          .uniq { |referral| [referral.from_name.downcase, referral.to_name.downcase] },
        # Nor can a share rule naming a file this case does not have. Dropping
        # it here rather than at import means the author reviews what will
        # actually exist, not a rule that will be silently discarded.
        share_rules: rows(payload["share_rules"])
          .filter_map { |row| share_rule(row, names, file_names) }
          .uniq { |rule| [rule.contact_name.downcase, rule.file_name] },
        notes: rows(payload["notes"], of: String).map { |note| clamp(note, TEXT_LIMIT) }.compact_blank
      )
    end

    # Two rows with the same name would show as two people on the review screen
    # and collapse into one on import, with the last row quietly winning. The
    # first one wins here instead, and visibly.
    #
    # Case-insensitively, because that is how the database keys a cast: leaving
    # "Dana Whitfield" and "dana whitfield" both in the proposal produces a
    # draft that can be reviewed but never accepted.
    def self.drafted_contacts(value)
      rows(value)
        .filter_map { |row| contact(row) }
        .uniq { |contact| contact.full_name.downcase }
    end

    def self.rows(value, of: Hash)
      Array(value).select { |row| row.is_a?(of) }
    end

    def self.contact(row)
      full_name = clamp(row["full_name"], NAME_LIMIT)
      system_prompt = clamp(row["system_prompt"], TEXT_LIMIT)
      return nil if full_name.blank? || system_prompt.blank?

      DraftedContact.new(
        full_name: full_name,
        role_title: clamp(row["role_title"], NAME_LIMIT).presence || "Contact",
        description: clamp(row["description"], TEXT_LIMIT).presence,
        system_prompt: system_prompt,
        in_starting_directory: boolean(row["in_starting_directory"])
      )
    end

    def self.referral(row, names)
      from_name = clamp(row["from_name"], NAME_LIMIT)
      to_name = clamp(row["to_name"], NAME_LIMIT)
      condition = clamp(row["condition"], TEXT_LIMIT)
      return nil unless names.include?(from_name) && names.include?(to_name)
      return nil if from_name == to_name || condition.blank?

      DraftedReferral.new(from_name: from_name, to_name: to_name, condition: condition)
    end

    def self.share_rule(row, names, file_names)
      contact_name = clamp(row["contact_name"], NAME_LIMIT)
      file_name = clamp(row["file_name"], NAME_LIMIT)
      condition = clamp(row["condition"], TEXT_LIMIT)
      return nil unless names.include?(contact_name)
      return nil if condition.blank? || file_name.blank?
      return nil if file_names && !file_names.include?(file_name)

      DraftedShareRule.new(contact_name: contact_name, file_name: file_name, condition: condition)
    end

    # "false" is a string, and a string is truthy. Without this, a provider that
    # renders the boolean as text puts everyone in the starting directory.
    def self.boolean(value)
      ActiveModel::Type::Boolean.new.cast(value) || false
    end

    def self.clamp(value, limit)
      return "" unless value.is_a?(String) || value.is_a?(Numeric)

      value.to_s.strip.truncate(limit)
    end
  end
end
