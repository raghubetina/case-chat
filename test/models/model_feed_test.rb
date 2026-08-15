require "test_helper"

# The feed exists because every fact in the catalogue goes stale on somebody
# else's schedule. What it has to get right is the filtering: the same payload
# carries our models under a dozen gateway namespaces at those gateways' own
# resale rates, and reading the wrong one bills the wrong number.
class ModelFeedTest < ActiveSupport::TestCase
  def payload(overrides = {})
    {
      "openai" => {"models" => {
        "gpt-5.6-sol" => {
          "name" => "GPT-5.6 Sol", "reasoning" => true,
          "reasoning_options" => [{"type" => "effort", "values" => %w[none low medium high xhigh max]}],
          "cost" => {"input" => 5, "output" => 30, "cache_read" => 0.5, "cache_write" => 6.25},
          "release_date" => "2026-07-09"
        }
      }},
      "anthropic" => {"models" => {
        "claude-sonnet-5" => {
          "name" => "Claude Sonnet 5", "reasoning" => true,
          "reasoning_options" => [{"type" => "toggle"},
            {"type" => "effort", "values" => %w[low medium high xhigh max]}],
          "cost" => {"input" => 2, "output" => 10, "cache_read" => 0.2, "cache_write" => 2.5},
          "release_date" => "2026-06-29"
        }
      }}
    }.deep_merge(overrides)
  end

  test "reads the models both providers publish" do
    models = ModelFeed.models_from(payload)

    assert_equal %w[claude-sonnet-5 gpt-5.6-sol], models.map(&:id).sort
    sol = models.find { |m| m.id == "gpt-5.6-sol" }
    assert_equal 5.0, sol.input_price
    assert_equal 30.0, sol.output_price
    assert_equal 6.25, sol.cache_write_price
  end

  # OpenRouter quotes gpt-5.6-terra at $1/$6 against OpenAI's $2/$12 in this
  # same payload. Billing from a gateway's namespace overcharges or undercharges
  # every call, and nothing downstream could tell.
  test "ignores gateways reselling the same models at their own rates" do
    with_gateway = payload("openrouter" => {"models" => {
      "gpt-5.6-sol" => {
        "name" => "GPT-5.6 Sol", "reasoning" => true,
        "reasoning_options" => [{"type" => "effort", "values" => %w[low]}],
        "cost" => {"input" => 1, "output" => 6}
      }
    }})

    sol = ModelFeed.models_from(with_gateway).select { |model| model.id == "gpt-5.6-sol" }

    assert_equal [5.0], sol.map(&:input_price), "one entry, at OpenAI's rate"
  end

  # A model can carry a toggle and an effort list. Taking the first entry gets
  # the toggle, which has no values at all.
  test "finds the effort list even when a toggle comes first" do
    sonnet = ModelFeed.models_from(payload).find { |m| m.id == "claude-sonnet-5" }

    assert_equal %w[low medium high xhigh max], sonnet.efforts
  end

  test "skips a deprecated model rather than offering it" do
    retired = payload("openai" => {"models" => {"gpt-4o" => {
      "name" => "GPT-4o", "reasoning" => true, "status" => "deprecated",
      "reasoning_options" => [{"type" => "effort", "values" => %w[low]}],
      "cost" => {"input" => 2.5, "output" => 10}
    }}})

    assert_not_includes ModelFeed.models_from(retired).map(&:id), "gpt-4o"
  end

  # Both selects have to be fillable. A model with no effort list has nothing to
  # put in the second one, and one with no price cannot be billed.
  test "skips a model it could not offer honestly" do
    partial = payload("openai" => {"models" => {
      "no-efforts" => {"name" => "X", "reasoning" => true, "cost" => {"input" => 1, "output" => 2}},
      "no-price" => {"name" => "Y", "reasoning" => true,
                     "reasoning_options" => [{"type" => "effort", "values" => %w[low]}], "cost" => {}},
      "no-reasoning" => {"name" => "Z", "reasoning" => false,
                         "reasoning_options" => [{"type" => "effort", "values" => %w[low]}],
                         "cost" => {"input" => 1, "output" => 2}}
    }})

    ids = ModelFeed.models_from(partial).map(&:id)

    assert_not_includes ids, "no-efforts"
    assert_not_includes ids, "no-price"
    assert_not_includes ids, "no-reasoning"
  end

  # A dropdown with nothing in it is worse than a stale one, and a reply must
  # not fail because a third party is down.
  test "the catalogue falls back to its own list when the feed gives nothing" do
    assert_empty ModelFeed.models, "tests never reach the network"
    assert_equal ModelCatalogue::FALLBACK, ModelCatalogue.all
    assert_not_nil ModelCatalogue.default
  end

  # The fallback is what answers during an outage, so it is the one list that
  # has to be right without a network to check it against.
  test "every fallback entry is priced and has efforts" do
    ModelCatalogue::FALLBACK.each do |entry|
      assert entry.input_price.positive?, "#{entry.id} has no input price"
      assert entry.output_price.positive?, "#{entry.id} has no output price"
      assert entry.efforts.any?, "#{entry.id} has no efforts"
      assert_includes Responder::ADAPTERS.keys, entry.provider
    end
  end
end
