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
  Reply = Data.define(:text, :introduced_contact_ids, :shared_document_ids, :usage) do
    def initialize(text:, introduced_contact_ids: [], shared_document_ids: [], usage: NULL_USAGE)
      super(
        text: text.to_s,
        introduced_contact_ids: Array(introduced_contact_ids).compact.uniq,
        shared_document_ids: Array(shared_document_ids).compact.uniq,
        usage: usage
      )
    end
  end

  class Error < StandardError; end

  # Which adapter answers as a contact. Set RESPONDER in the environment.
  # Selection is explicit rather than inferred from which API keys happen to be
  # present: with several keys configured, key-sniffing silently picks a winner
  # and nobody can tell from the code which model is in play.
  ADAPTERS = {
    "anthropic" => -> { Anthropic.new },
    "openai" => -> { OpenAI.new },
    "fake" => -> { Fake.new }
  }.freeze

  DEFAULT_ADAPTER = "anthropic".freeze

  class << self
    attr_writer :current

    def current
      @current ||= build(configured_name)
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

    def configured_name
      # Tests never reach a provider, whatever the environment says.
      return "fake" if Rails.env.test?

      ENV.fetch("RESPONDER", DEFAULT_ADAPTER).downcase
    end

    private

    def build(name)
      factory = ADAPTERS[name]
      raise Error, "Unknown RESPONDER #{name.inspect}. Known: #{ADAPTERS.keys.join(", ")}" if factory.nil?

      factory.call
    end
  end
end
