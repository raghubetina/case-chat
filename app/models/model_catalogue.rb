# The models an author may put behind a stakeholder.
#
# A closed list rather than a free-text field: a typo in a model id fails at the
# provider, mid-reply, in a job, which is the worst place to find out. Every id
# below was checked against the provider's own models endpoint.
#
# The model implies its provider, so a stakeholder stores one value and the two
# can never disagree.
class ModelCatalogue
  Entry = Data.define(:id, :provider, :label, :efforts, :input_price, :output_price, :cache_read_price)

  # Prices are dollars per million tokens, and they are here only so cost can be
  # totalled without a second lookup. Anthropic's are the published list rates.
  # OpenAI's are left nil deliberately: the 5.6 variants' rates were not
  # verified when this was written, and a made-up price in a cost report is
  # worse than a blank, because a blank prompts someone to go and find out.
  ENTRIES = [
    Entry.new(id: "claude-opus-5", provider: "anthropic", label: "Claude Opus 5",
      efforts: %w[low medium high xhigh max],
      input_price: 5.00, output_price: 25.00, cache_read_price: 0.50),
    Entry.new(id: "claude-sonnet-5", provider: "anthropic", label: "Claude Sonnet 5",
      efforts: %w[low medium high xhigh max],
      input_price: 3.00, output_price: 15.00, cache_read_price: 0.30),
    Entry.new(id: "gpt-5.6-sol", provider: "openai", label: "GPT-5.6 Sol",
      efforts: %w[minimal low medium high xhigh],
      input_price: nil, output_price: nil, cache_read_price: nil),
    Entry.new(id: "gpt-5.6-terra", provider: "openai", label: "GPT-5.6 Terra",
      efforts: %w[minimal low medium high xhigh],
      input_price: nil, output_price: nil, cache_read_price: nil),
    Entry.new(id: "gpt-5.6-luna", provider: "openai", label: "GPT-5.6 Luna",
      efforts: %w[minimal low medium high xhigh],
      input_price: nil, output_price: nil, cache_read_price: nil)
  ].freeze

  BY_ID = ENTRIES.index_by(&:id).freeze

  # What answers as a stakeholder whose author has not picked anything.
  #
  # It lives here rather than in an adapter because the deployment default is a
  # model like any other: it should have a known price, a checked id, and an
  # effort the catalogue agrees that model accepts. The previous default was a
  # bare id no entry described, so the commonest case in the app was the one
  # nothing could report on.
  DEFAULT_ID = "gpt-5.6-sol".freeze
  DEFAULT_EFFORT = "high".freeze

  class << self
    def all = ENTRIES

    def find(id) = BY_ID[id.to_s]

    def default = find(DEFAULT_ID)

    def ids = BY_ID.keys

    def efforts_for(id) = find(id)&.efforts || []

    # Every effort any model accepts, for validating a stored value against a
    # stakeholder whose model was changed afterwards.
    def all_efforts = ENTRIES.flat_map(&:efforts).uniq

    def grouped_for_select
      ENTRIES.group_by(&:provider).transform_values { |entries| entries.map { |e| [e.label, e.id] } }
    end

    # Dollars, or nil when a price is unknown — the caller decides whether to
    # show a blank or a total, and neither should be invented here.
    def cost(model:, input_tokens:, output_tokens:, cache_read_tokens: 0)
      entry = find(model)
      return nil if entry.nil? || entry.input_price.nil?

      fresh_input = [input_tokens - cache_read_tokens, 0].max
      (fresh_input * entry.input_price +
        cache_read_tokens * entry.cache_read_price +
        output_tokens * entry.output_price) / 1_000_000.0
    end
  end
end
