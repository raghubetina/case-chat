module CaseDrafter
  # What we ask a model to do when reading a teaching case.
  #
  # The instruction that matters is the last one: split the material so that
  # what a student is handed is thin, and what they must earn sits with the
  # person who would plausibly hold it. A draft that puts everything in the
  # background is a correct summary and a useless case.
  module Prompt
    INSTRUCTIONS = <<~TEXT.strip
      You are helping an instructor turn an existing teaching case into an
      interview-based case, where students learn by interviewing the people in
      it rather than by reading a handout.

      Read the attached documents and propose a structure.

      ## What goes where

      - `background` is what every student is handed at the start. Keep it thin.
        Anything you put here is information the student does not have to earn.
        Setting, the question, and the physical facts nobody disputes.
      - `assignment` is what they must deliver, in the instructor's voice.
      - `contacts` are the people in the case. For each, write a `system_prompt`
        in the second person that says who they are, what they know, what they
        will not volunteer, and how they speak. Withholding is the point: a cast
        where everyone answers everything is not a case.
      - `in_starting_directory` is true only for the two or three people a
        student can obviously approach first. Everyone else must be reachable
        through a referral.
      - `referrals` say who hands the student to whom, and on what cue. Every
        contact who is not in the starting directory MUST be the target of at
        least one referral, or no student will ever meet them.
      - `share_rules` say which document a contact hands over and what the
        student must have asked first. Use the exact file names given below.

      ## How to think about the split

      Where the source material states a fact that only one person could
      plausibly know, put it in that person's system prompt rather than in the
      background — and add the referral that makes them reachable. Where the
      material disagrees with itself, that disagreement is the case: give the
      two positions to two different people.

      Do not invent people who are not in the material. If the material implies
      a role without naming a person, you may name them, and say so in `notes`.
    TEXT

    def self.for(documents:, hint:)
      names = documents.map(&:file_name)

      <<~TEXT.strip
        #{INSTRUCTIONS}

        ## Files available to be shared by contacts

        #{names.map { |name| "- #{name}" }.join("\n")}
        #{"\n## What the instructor said\n\n#{hint}" if hint.present?}
      TEXT
    end

    # A schema both providers can enforce, so the draft arrives structured
    # rather than as prose we would have to parse back apart.
    #
    # Every property is listed in `required`, and anything genuinely optional is
    # nullable instead of absent. That is not a stylistic choice: OpenAI's
    # strict structured outputs rejects the whole request with a 400 unless
    # `required` names every key in `properties`. Optional-by-omission is
    # exactly what it refuses.
    SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[title course background assignment notes contacts referrals share_rules],
      properties: {
        title: {type: "string"},
        course: {type: %w[string null]},
        background: {type: "string"},
        assignment: {type: "string"},
        notes: {
          type: "array",
          items: {type: "string"},
          description: "Anything the instructor should check: invented names, thin roles, material you could not place."
        },
        contacts: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: %w[full_name role_title description system_prompt in_starting_directory],
            properties: {
              full_name: {type: "string"},
              role_title: {type: "string"},
              description: {type: %w[string null], description: "One or two sentences, shown to students in the directory."},
              system_prompt: {type: "string", description: "Second person. What they know, what they withhold, how they speak."},
              in_starting_directory: {type: "boolean"}
            }
          }
        },
        referrals: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: %w[from_name to_name condition],
            properties: {
              from_name: {type: "string"},
              to_name: {type: "string"},
              condition: {type: "string", description: "The cue that should trigger the handoff."}
            }
          }
        },
        share_rules: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: %w[contact_name file_name condition],
            properties: {
              contact_name: {type: "string"},
              file_name: {type: "string"},
              condition: {type: "string"}
            }
          }
        }
      }
    }.freeze
  end
end
