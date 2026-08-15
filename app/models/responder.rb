# The seam between Case Chat and whichever model actually answers as a contact.
#
# This exists so provider choice is ours rather than a dependency's: the app
# talks to Responder, and Responder::Anthropic is the only file that knows what
# an Anthropic request looks like. Tests and development run Responder::Fake,
# which is deterministic and never opens a socket.
module Responder
  # Cache hits are the whole cost story for this app, so carry them explicitly
  # rather than burying them in a provider-shaped hash.
  Usage = Data.define(:input_tokens, :output_tokens, :cache_read_tokens, :cache_write_tokens) do
    def cached? = cache_read_tokens.to_i.positive?
  end

  NULL_USAGE = Usage.new(input_tokens: 0, output_tokens: 0, cache_read_tokens: 0, cache_write_tokens: 0)

  # What a contact said, plus the structured things they did while saying it.
  # The id lists are normalized here so no adapter can hand the pipeline a nil,
  # and every caller can iterate without guarding.
  Reply = Data.define(:text, :introduced_contact_ids, :shared_document_ids,
    :introduction_reasons, :reasoning_blocks, :usage, :raw) do
    def initialize(text:, introduced_contact_ids: [], shared_document_ids: [],
      introduction_reasons: [], reasoning_blocks: [], usage: NULL_USAGE, raw: nil)
      super(
        text: text.to_s,
        introduced_contact_ids: Array(introduced_contact_ids).compact.uniq,
        shared_document_ids: Array(shared_document_ids).compact.uniq,
        introduction_reasons: Array(introduction_reasons).map { |line| line.to_s.strip }.reject(&:empty?),
        # The turn as the provider produced it, for the next turn to hand back.
        reasoning_blocks: Array(reasoning_blocks),
        usage: usage,
        raw: raw
      )
    end

    # What this person actually said out loud.
    #
    # Introducing someone is a tool call, and a model that makes one often
    # writes no prose alongside it — which used to reach the student as a
    # contact card under an empty bubble, as though the handoff came from
    # nowhere. The tool asks for a sentence in the contact's own voice for
    # exactly this reason, so when there is no prose, that sentence is the
    # reply. Prose wins when there is any: saying it twice is worse than
    # either.
    def spoken_text
      return text if text.present?

      introduction_reasons.join("\n\n")
    end
  end

  class Error < StandardError; end

  # Which adapter answers as a contact. Set RESPONDER in the environment.
  # Selection is explicit rather than inferred from which API keys happen to be
  # present: with several keys configured, key-sniffing silently picks a winner
  # and nobody can tell from the code which model is in play.
  ADAPTERS = {
    "anthropic" => ->(**kwargs) { Anthropic.new(**kwargs) },
    "openai" => ->(**kwargs) { OpenAI.new(**kwargs) },
    "fake" => ->(**) { Fake.new }
  }.freeze

  DEFAULT_ADAPTER = "openai".freeze

  class << self
    attr_writer :current

    # The deployment default: the catalogue's default model at its stated
    # effort, as long as RESPONDER still names that model's provider. Flipping
    # RESPONDER to the other provider is a wholesale escape hatch, and it gets
    # that provider's own defaults rather than an effort chosen for a different
    # model.
    def current
      @current ||= begin
        entry = ModelCatalogue.default
        if entry && configured_name == entry.provider
          build(entry.provider, model: entry.id, effort: ModelCatalogue::DEFAULT_EFFORT)
        else
          build(configured_name)
        end
      end
    end

    # Swap the responder for the duration of a block. Used by tests that want
    # to assert on a specific reply without reaching for a mocking library.
    def with(responder)
      previous = current
      self.current = responder
      yield
    ensure
      self.current = previous
    end

    def reset! = @current = nil

    # The adapter that answers as this stakeholder. A model chosen on the
    # stakeholder wins; otherwise the deployment's default answers, which is
    # what every contact did before the column existed.
    #
    # Tests and an explicitly injected responder still win over both, so
    # Responder.with continues to work on this path.
    def for(contact)
      return current if @current || Rails.env.test?

      entry = ModelCatalogue.find(contact.model)
      return current if entry.nil?

      build(entry.provider, model: entry.id, effort: contact.effort.presence)
    end

    # The catalogue keys on provider, and an adapter knows its own class.
    def provider_name(adapter)
      case adapter
      when Anthropic then "anthropic"
      when OpenAI then "openai"
      else "fake"
      end
    end

    def configured_name
      # Tests never reach a provider, whatever the environment says.
      return "fake" if Rails.env.test?

      ENV.fetch("RESPONDER", DEFAULT_ADAPTER).downcase
    end

    private

    def build(name, **kwargs)
      factory = ADAPTERS[name]
      raise Error, "Unknown RESPONDER #{name.inspect}. Known: #{ADAPTERS.keys.join(", ")}" if factory.nil?

      factory.call(**kwargs)
    end
  end
end
