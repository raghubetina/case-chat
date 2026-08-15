# The models an author may put behind a person, and what each costs.
#
# A closed list rather than a free-text field: a typo in a model id fails at
# the provider, mid-reply, in a job, which is the worst place to find out. The
# list is no longer written down here, though. It comes from ModelFeed, because
# every fact in it goes stale on somebody else's schedule -- prices change,
# effort values are renamed, models are deprecated -- and a table maintained by
# hand records the day somebody last looked rather than the current truth.
#
# FALLBACK below is what answers when the feed cannot be reached. It is
# deliberately small: the five models this app was built against, at the rates
# and efforts confirmed from both providers' own pages on 15 August 2026. It
# exists so a network failure cannot empty the dropdown or stop a reply, not as
# a second source of truth.
class ModelCatalogue
  Entry = Data.define(:id, :provider, :label, :efforts, :input_price, :output_price,
    :cache_read_price, :cache_write_price)

  FALLBACK = [
    Entry.new(id: "gpt-5.6-sol", provider: "openai", label: "GPT-5.6 Sol",
      efforts: %w[none low medium high xhigh max],
      input_price: 5.00, output_price: 30.00, cache_read_price: 0.50, cache_write_price: 6.25),
    Entry.new(id: "gpt-5.6-terra", provider: "openai", label: "GPT-5.6 Terra",
      efforts: %w[none low medium high xhigh max],
      input_price: 2.00, output_price: 12.00, cache_read_price: 0.20, cache_write_price: 2.50),
    Entry.new(id: "gpt-5.6-luna", provider: "openai", label: "GPT-5.6 Luna",
      efforts: %w[none low medium high xhigh max],
      input_price: 0.20, output_price: 1.20, cache_read_price: 0.02, cache_write_price: 0.25),
    Entry.new(id: "claude-opus-5", provider: "anthropic", label: "Claude Opus 5",
      efforts: %w[low medium high xhigh max],
      input_price: 5.00, output_price: 25.00, cache_read_price: 0.50, cache_write_price: 6.25),
    Entry.new(id: "claude-sonnet-5", provider: "anthropic", label: "Claude Sonnet 5",
      efforts: %w[low medium high xhigh max],
      input_price: 2.00, output_price: 10.00, cache_read_price: 0.20, cache_write_price: 2.50)
  ].freeze

  # What answers for a person whose author has not chosen. Named here rather
  # than in an adapter because the deployment default is a model like any
  # other: it should have a checked id, a known price, and an effort the model
  # accepts.
  DEFAULT_ID = "gpt-5.6-sol".freeze
  DEFAULT_EFFORT = "high".freeze

  class << self
    def all
      feed = ModelFeed.models
      return FALLBACK if feed.empty?

      feed.map { |model| Entry.new(**model.to_h.except(:released_on)) }
    end

    def find(id) = all.find { |entry| entry.id == id.to_s }

    def ids = all.map(&:id)

    def default = find(DEFAULT_ID) || FALLBACK.first

    def efforts_for(id) = find(id)&.efforts || []

    # Every effort any listed model accepts. A stored value is validated
    # against its own model, so this is only the outer bound for a select.
    def all_efforts = all.flat_map(&:efforts).uniq

    def grouped_for_select
      all.group_by(&:provider).transform_values { |entries| entries.map { |e| [e.label, e.id] } }
    end

    # The efforts each model accepts, for the browser to narrow the second
    # select when the first one changes.
    def efforts_by_id = all.to_h { |entry| [entry.id, entry.efforts] }

    # Dollars, or nil when the model is not one we know. Used to stamp a rate
    # onto a call as it is made; reading a past call's cost goes through the
    # rates stored on the row instead, so that history cannot move.
    def cost(model:, input_tokens:, output_tokens:, cache_read_tokens: 0)
      entry = find(model)
      return nil if entry.nil?

      ModelCall.price(
        input_tokens: input_tokens, output_tokens: output_tokens,
        cache_read_tokens: cache_read_tokens,
        input_price: entry.input_price, output_price: entry.output_price,
        cache_read_price: entry.cache_read_price
      )
    end
  end
end
