# The published catalogue of models, their prices, and the reasoning efforts
# each one accepts, read from models.dev.
#
# It is here because a hardcoded price is wrong the moment a provider changes
# one, and neither provider publishes prices in an API. Claude Sonnet 5 proved
# it: its rate was correct when somebody typed it in and became 50% too high
# when Anthropic made an introductory price permanent, with nothing in this app
# able to notice. The effort lists were wrong the same way, from reading
# OpenAI's family-wide union page instead of the per-model one, which offered
# authors a value the provider rejects mid-reply.
#
# Only the `openai` and `anthropic` keys are read. The same feed carries the
# same models under a dozen gateway namespaces at those gateways' own resale
# rates -- OpenRouter quotes gpt-5.6-terra at $1/$6 against OpenAI's $2/$12 --
# and this app bills the providers directly.
class ModelFeed
  URL = "https://models.dev/api.json".freeze
  PROVIDERS = %w[openai anthropic].freeze
  CACHE_KEY = "model_feed/entries/v1".freeze
  TTL = 12.hours
  TIMEOUT = 5

  Model = Data.define(:id, :provider, :label, :efforts, :input_price, :output_price,
    :cache_read_price, :cache_write_price, :released_on)

  class << self
    # Never raises and never blocks a reply. A failed fetch keeps whatever was
    # cached; an empty cache falls through to the caller's own list, because a
    # dropdown with nothing in it is worse than a stale one.
    def models
      return [] unless fetching?

      Rails.cache.fetch(CACHE_KEY, expires_in: TTL) { fetch } || []
    rescue => e
      Rails.logger.warn("[model_feed] #{e.class}: #{e.message}")
      []
    end

    def refresh!
      Rails.cache.delete(CACHE_KEY)
      models
    end

    # Tests never reach the network. Webmock's refusal does not descend from
    # StandardError, so it would bypass the rescue above and fail the suite
    # rather than exercise the fallback. Parsing is tested against a fixture
    # through models_from instead.
    def fetching? = !Rails.env.test?

    # Public so a test can drive the parse with a recorded payload rather than
    # a socket.
    def models_from(payload) = parse(payload)

    private

    def fetch
      body = get(URL)
      return nil if body.nil?

      parse(JSON.parse(body))
    rescue JSON::ParserError => e
      # A typo'd path on this host redirects to a 1.7MB HTML page rather than
      # returning 404, so malformed JSON is a routine failure, not a surprise.
      Rails.logger.warn("[model_feed] unparseable response: #{e.message}")
      nil
    end

    def get(url)
      response = Net::HTTP.get_response(URI(url), {"Accept" => "application/json"})
      return response.body if response.is_a?(Net::HTTPSuccess)

      Rails.logger.warn("[model_feed] #{url} returned #{response.code}")
      nil
    end

    def parse(payload)
      PROVIDERS.flat_map { |provider|
        (payload.dig(provider, "models") || {}).filter_map do |id, record|
          model_from(id, provider, record)
        end
      }.sort_by { |model| [model.provider, -model.input_price] }
    end

    # Skipped: anything the app cannot offer honestly. A model with no effort
    # list has nothing to put in the second select, one with no price cannot be
    # billed, and a deprecated one is a trap to hand an author.
    def model_from(id, provider, record)
      return nil unless record["reasoning"]
      return nil if record["status"] == "deprecated"

      efforts = effort_values(record)
      cost = record["cost"] || {}
      return nil if efforts.blank? || cost["input"].nil? || cost["output"].nil?

      Model.new(
        id: id, provider: provider, label: record["name"].presence || id,
        efforts: efforts,
        input_price: cost["input"].to_f, output_price: cost["output"].to_f,
        cache_read_price: cost["cache_read"]&.to_f, cache_write_price: cost["cache_write"]&.to_f,
        released_on: record["release_date"]
      )
    end

    # `reasoning_options` is a list of option objects, and a model can carry
    # both a toggle and an effort list, so this selects by type rather than
    # taking the first entry.
    def effort_values(record)
      Array(record["reasoning_options"])
        .find { |option| option["type"] == "effort" }
        &.fetch("values", nil)
        .then { |values| Array(values).map(&:to_s) }
    end
  end
end
