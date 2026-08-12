module Responder
  # A deterministic stand-in used in tests and in development without a key.
  #
  # It is not a mock: it exercises the same contract the real adapter does,
  # including firing referrals and document shares, so the pipeline around it
  # (persisting messages, creating Introductions and DocumentShares, rendering
  # cards) is genuinely tested rather than stubbed past.
  #
  # The rule it plays by is deliberately crude and stated plainly: a rule fires
  # when a significant word from its condition appears in the student's last
  # message. That is not how the real model decides, and it is not trying to be
  # — it just needs to be predictable enough to assert on.
  class Fake
    STOPWORDS = %w[
      when the student asks about a an and or if for to of in on at is are be
      once only do not does has have with what which that this it they them
      their pushes push raises raise ask asked asking
    ].to_set.freeze

    attr_reader :calls

    def initialize(text: nil)
      @text = text
      @calls = []
    end

    def reply(briefing:, history:)
      last = history.rfind { |message| !message.from_contact? }
      prompt = last&.body.to_s.downcase
      @calls << {contact: briefing.contact.full_name, prompt: prompt}

      Reply.new(
        text: @text || "#{briefing.contact.full_name} here. #{canned_answer(prompt)}",
        introduced_contact_ids: triggered_referral_ids(briefing, prompt),
        shared_document_ids: triggered_document_ids(briefing, prompt),
        usage: Usage.new(
          input_tokens: 100, output_tokens: 40,
          cache_read_tokens: (history.size > 1) ? 80 : 0,
          cache_write_tokens: (history.size > 1) ? 0 : 80
        )
      )
    end

    private

    def canned_answer(prompt)
      return "What do you need?" if prompt.blank?

      "Let me take that one."
    end

    def triggered_referral_ids(briefing, prompt)
      briefing.send(:referrals).filter_map do |referral|
        referral.referred_contact_id if matches?(referral.condition, prompt)
      end
    end

    def triggered_document_ids(briefing, prompt)
      briefing.send(:share_rules).filter_map do |rule|
        rule.document_id if matches?(rule.condition, prompt)
      end
    end

    def matches?(condition, prompt)
      return false if prompt.blank?

      significant_words(condition).any? { |word| prompt.include?(word) }
    end

    def significant_words(condition)
      condition.to_s.downcase.scan(/[a-z]{4,}/).reject { |word| STOPWORDS.include?(word) }
    end
  end
end
