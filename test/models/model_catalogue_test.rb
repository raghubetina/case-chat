require "test_helper"

# The catalogue is the only place that knows which model ids are real and which
# provider answers for each. Every id here was checked against the provider's
# own models endpoint; a typo would fail at the provider, mid-reply, in a job.
class ModelCatalogueTest < ActiveSupport::TestCase
  test "every catalogued model names a provider we have an adapter for" do
    ModelCatalogue::ENTRIES.each do |entry|
      assert_includes Responder::ADAPTERS.keys, entry.provider,
        "#{entry.id} names a provider with no adapter"
    end
  end

  # Most stakeholders will never have a model picked for them, so the default is
  # the entry that answers most often. A default naming an id no entry describes
  # is one the cost report cannot price and the effort list cannot validate.
  test "the deployment default is a real catalogued model" do
    assert_not_nil ModelCatalogue.default, "#{ModelCatalogue::DEFAULT_ID} is not in the catalogue"
    assert_equal Responder::DEFAULT_ADAPTER, ModelCatalogue.default.provider,
      "RESPONDER's default provider and the default model must not drift apart"
  end

  test "the default effort is one the default model accepts" do
    assert_includes ModelCatalogue.efforts_for(ModelCatalogue::DEFAULT_ID),
      ModelCatalogue::DEFAULT_EFFORT
  end

  test "the model implies its provider, so the two cannot disagree" do
    assert_equal "anthropic", ModelCatalogue.find("claude-opus-5").provider
    assert_equal "openai", ModelCatalogue.find("gpt-5.6-luna").provider
  end

  # The providers do not offer the same levels: OpenAI has minimal, Anthropic
  # has max. A stakeholder validates its effort against its own model.
  test "effort levels are per model, not shared" do
    assert_includes ModelCatalogue.efforts_for("gpt-5.6-sol"), "minimal"
    assert_not_includes ModelCatalogue.efforts_for("gpt-5.6-sol"), "max"
    assert_includes ModelCatalogue.efforts_for("claude-opus-5"), "max"
    assert_not_includes ModelCatalogue.efforts_for("claude-opus-5"), "minimal"
  end

  test "an unknown model is simply not found" do
    assert_nil ModelCatalogue.find("gpt-9-imaginary")
    assert_empty ModelCatalogue.efforts_for("gpt-9-imaginary")
  end

  # Cached input is billed at a fraction of fresh input, which is the whole
  # reason the briefing carries a cache breakpoint.
  test "cost bills cached input at the cache rate" do
    cold = ModelCatalogue.cost(model: "claude-opus-5", input_tokens: 1_000_000, output_tokens: 0)
    warm = ModelCatalogue.cost(model: "claude-opus-5", input_tokens: 1_000_000,
      output_tokens: 0, cache_read_tokens: 1_000_000)

    assert_in_delta 5.00, cold, 0.001
    assert_in_delta 0.50, warm, 0.001
    assert_operator warm, :<, cold
  end

  # A blank prompts someone to go and find the rate. An invented number is a
  # wrong answer that looks right.
  test "cost is nil rather than guessed when a price is unknown" do
    assert_nil ModelCatalogue.find("gpt-5.6-luna").input_price
    assert_nil ModelCatalogue.cost(model: "gpt-5.6-luna", input_tokens: 1000, output_tokens: 1000)
    assert_nil ModelCatalogue.cost(model: "not-a-model", input_tokens: 1000, output_tokens: 1000)
  end
end
