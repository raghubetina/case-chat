require "test_helper"

# The catalogue is the only place that knows which model ids are real and which
# provider answers for each; a typo would fail at the provider, mid-reply, in a
# job. The list now comes from ModelFeed, and these assertions run against
# FALLBACK, which is what answers when the feed cannot be reached and therefore
# the one list that has to be right without a network.
class ModelCatalogueTest < ActiveSupport::TestCase
  test "every catalogued model names a provider we have an adapter for" do
    ModelCatalogue::FALLBACK.each do |entry|
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

  # The providers do not share a vocabulary. OpenAI's floor is "none";
  # Anthropic's is "low" and it has no "none" at all. Both reach "max" on these
  # models. A person validates their effort against their own model.
  #
  # This test used to assert the opposite -- that gpt-5.6 offered "minimal" and
  # not "max" -- which came from reading OpenAI's family-wide union page rather
  # than the per-model one. It was green, and it was holding the bug in place:
  # "minimal" is rejected by every 5.6 model, so an author who picked it got a
  # provider error mid-reply, which is exactly what a closed list exists to stop.
  test "effort levels are per model, not shared" do
    assert_includes ModelCatalogue.efforts_for("gpt-5.6-sol"), "none"
    assert_includes ModelCatalogue.efforts_for("gpt-5.6-sol"), "max"
    assert_not_includes ModelCatalogue.efforts_for("gpt-5.6-sol"), "minimal"
    assert_includes ModelCatalogue.efforts_for("claude-opus-5"), "max"
    assert_not_includes ModelCatalogue.efforts_for("claude-opus-5"), "none"
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
  # wrong answer that looks right. Every catalogued model is priced today, so
  # the surviving path is a model this app has never heard of -- which is what a
  # stakeholder left on a retired id would report.
  test "cost is nil rather than guessed for a model we do not know" do
    assert_nil ModelCatalogue.find("not-a-model")
    assert_nil ModelCatalogue.cost(model: "not-a-model", input_tokens: 1000, output_tokens: 1000)
  end

  # Reading the provider's own page is what fills these in, so a new entry
  # arrives unpriced and stays that way until someone does. Cost has to survive
  # that rather than treat the blank as free.
  test "an unpriced entry yields no cost rather than a zero" do
    unpriced = ModelCatalogue::Entry.new(
      id: "gpt-5.7-unreleased", provider: "openai", label: "Unreleased",
      efforts: %w[low], input_price: nil, output_price: nil,
      cache_read_price: nil, cache_write_price: nil
    )

    stub_const(ModelCatalogue, :FALLBACK, ModelCatalogue::FALLBACK + [unpriced]) do
      assert_nil ModelCatalogue.cost(model: unpriced.id, input_tokens: 1000, output_tokens: 1000)
    end
  end

  # The editor's select opens on this, and its Stimulus controller repeats the
  # same three steps when the model changes, so a level rendered by the server
  # and one chosen in the browser cannot disagree.
  test "keeps a stored effort the model still offers" do
    assert_equal "max", ModelCatalogue.resolved_effort("claude-opus-5", "max")
  end

  test "falls back to the deployment default when the stored effort is not offered" do
    assert_not_includes ModelCatalogue.efforts_for("claude-opus-5"), "none"

    assert_equal ModelCatalogue::DEFAULT_EFFORT,
      ModelCatalogue.resolved_effort("claude-opus-5", "none")
  end

  # Every catalogued model happens to offer the default today, so this branch is
  # unreachable through real data -- and it is the branch that decides what a
  # model added tomorrow opens on.
  test "falls back to the model's own first level when it does not offer the default" do
    original = ModelCatalogue.method(:efforts_for)
    ModelCatalogue.define_singleton_method(:efforts_for) { |_id| ["brisk", "brisker"] }

    assert_equal "brisk", ModelCatalogue.resolved_effort("any-model", "none")
    assert_equal "brisker", ModelCatalogue.resolved_effort("any-model", "brisker")
  ensure
    ModelCatalogue.define_singleton_method(:efforts_for, original)
  end

  test "resolves without a stored effort" do
    assert_includes ModelCatalogue.efforts_for("claude-opus-5"),
      ModelCatalogue.resolved_effort("claude-opus-5", nil)
  end

  # The line beside the model select. nil rather than zero for an unpriced model,
  # so the view can say so instead of claiming it is free.
  test "reports prices per model and nothing for an unknown one" do
    assert_equal({input: 5.00, output: 30.00}, ModelCatalogue.prices_for("gpt-5.6-sol"))
    assert_nil ModelCatalogue.prices_for("gpt-9-imaginary")
  end
end
