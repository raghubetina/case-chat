require "test_helper"
require_relative "domain_test_helper"

# A schema is a request, not a guarantee. Every test here is a shape a provider
# can legally return that used to crash the parser, corrupt the cast, or reach
# the review screen claiming something the import would silently discard.
class CaseDrafterTest < ActiveSupport::TestCase
  include DomainTestHelper

  def payload(**overrides)
    {
      "title" => "Meridian",
      "contacts" => [
        {"full_name" => "June", "role_title" => "GM", "system_prompt" => "You are June.", "in_starting_directory" => true},
        {"full_name" => "Marco", "role_title" => "Chef", "system_prompt" => "You are Marco.", "in_starting_directory" => false}
      ],
      "referrals" => [{"from_name" => "June", "to_name" => "Marco", "condition" => "when asked about the line"}],
      "share_rules" => [{"contact_name" => "June", "file_name" => "brief.pdf", "condition" => "when asked"}]
    }.merge(overrides)
  end

  test "refuses a payload that is not an object" do
    [nil, "a draft", 42, []].each do |junk|
      assert_raises(CaseDrafter::Error) { CaseDrafter::Parser.call(junk) }
    end
  end

  test "refuses a draft with no usable contact rather than proposing an empty cast" do
    assert_raises(CaseDrafter::Error) { CaseDrafter::Parser.call({}) }
    assert_raises(CaseDrafter::Error) { CaseDrafter::Parser.call(payload("contacts" => [nil, 42, {}, "June"])) }
  end

  test "skips unusable rows without taking the whole draft down" do
    draft = CaseDrafter::Parser.call(payload("contacts" => [nil, payload["contacts"].first, {"full_name" => "No prompt"}]))

    assert_equal ["June"], draft.contacts.map(&:full_name)
  end

  test "reads a string boolean as the boolean it renders" do
    row = payload["contacts"].first.merge("in_starting_directory" => "false")

    draft = CaseDrafter::Parser.call(payload("contacts" => [row]))

    assert_not draft.contacts.first.in_starting_directory,
      %(a provider that renders the boolean as "false" must not put everyone in the starting directory)
  end

  test "collapses names that differ only in case, because the database does" do
    rows = [
      {"full_name" => "Dana Whitfield", "role_title" => "CFO", "system_prompt" => "first"},
      {"full_name" => "dana whitfield", "role_title" => "Host", "system_prompt" => "second"}
    ]

    draft = CaseDrafter::Parser.call(payload("contacts" => rows))

    assert_equal 1, draft.contacts.size,
      "keeping both produces a draft that can be reviewed but never accepted"
  end

  test "collapses referrals and share rules that would import as one row" do
    draft = CaseDrafter::Parser.call(
      payload(
        "referrals" => [
          {"from_name" => "June", "to_name" => "Marco", "condition" => "when asked about staffing"},
          {"from_name" => "June", "to_name" => "Marco", "condition" => "when asked about costs"}
        ],
        "share_rules" => [
          {"contact_name" => "June", "file_name" => "brief.pdf", "condition" => "when asked"},
          {"contact_name" => "June", "file_name" => "brief.pdf", "condition" => "when pressed"}
        ]
      ),
      file_names: Set["brief.pdf"]
    )

    assert_equal 1, draft.referrals.size, "the pair is the fact; two rows import as one"
    assert_equal "when asked about staffing", draft.referrals.first.condition
    assert_equal 1, draft.share_rules.size
  end

  test "collapses duplicate names at review time rather than silently at import" do
    rows = [
      {"full_name" => "June", "role_title" => "GM", "system_prompt" => "first"},
      {"full_name" => "June", "role_title" => "Host", "system_prompt" => "second"}
    ]

    draft = CaseDrafter::Parser.call(payload("contacts" => rows))

    assert_equal 1, draft.contacts.size
    assert_equal "first", draft.contacts.first.system_prompt, "the row shown should be the row applied"
  end

  test "drops a referral naming someone outside the cast" do
    rows = [{"from_name" => "June", "to_name" => "Nobody", "condition" => "never"}]

    assert_empty CaseDrafter::Parser.call(payload("referrals" => rows)).referrals
  end

  test "drops a share rule naming a file the case does not have" do
    draft = CaseDrafter::Parser.call(payload, file_names: Set["something_else.pdf"])

    assert_empty draft.share_rules,
      "a rule the import would discard must not be reviewed as if it were real"
  end

  test "keeps a share rule whose file exists" do
    draft = CaseDrafter::Parser.call(payload, file_names: Set["brief.pdf"])

    assert_equal ["brief.pdf"], draft.share_rules.map(&:file_name)
  end

  test "clamps a title that would not fit the column it lands in" do
    draft = CaseDrafter::Parser.call(payload("title" => "V" * 500))

    assert_equal CaseDrafter::Parser::TITLE_LIMIT, draft.title.length
    assert CaseStudy.new(title: draft.title, author: build_user).valid?
  end

  test "survives a schema-valid draft round-tripping through the database" do
    original = CaseDrafter::Parser.call(payload, file_names: Set["brief.pdf"])

    restored = CaseDrafter.deserialize(JSON.parse(CaseDrafter.serialize(original).to_json))

    assert_equal original, restored
  end

  test "an unknown provider fails loudly instead of quietly returning canned material" do
    # A typo in RESPONDER used to select the fake drafter, which proposes a
    # canned cast without reading anything — and the author would accept that
    # invented cast believing a model had read their case.
    error = assert_raises(CaseDrafter::Error) { CaseDrafter.adapter_for("openia") }

    assert_match(/openia/, error.message)
  end

  test "every configured provider name resolves to a drafter" do
    CaseDrafter::ADAPTERS.each_key do |name|
      assert_respond_to CaseDrafter.adapter_for(name), :draft, "#{name} must implement draft"
    end
  end

  # These two shapes were each rejected with a real 400 in production form. They
  # are pinned here because no fake can catch them: the request looks perfectly
  # reasonable right up until a provider validates it.
  test "the schema OpenAI is sent lists every property as required" do
    schema = CaseDrafter::Prompt::SCHEMA

    assert_strictly_required(schema)
  end

  test "a text file is sent as text, not as a base64 PDF" do
    document = attached_document("rows.csv", "text/csv", "a,b\n1,2\n")

    block = CaseDrafter::Anthropic.new(client: :unused).send(:document_block, document)

    assert_equal :text, block.dig(:source, :type).to_sym
    assert_equal "text/plain", block.dig(:source, :media_type),
      "the base64 source accepts application/pdf and nothing else"
    assert_equal "a,b\n1,2\n", block.dig(:source, :data), "text is sent unencoded"
  end

  test "a PDF is still sent as a base64 document" do
    document = attached_document("case.pdf", "application/pdf", "%PDF-1.4")

    block = CaseDrafter::Anthropic.new(client: :unused).send(:document_block, document)

    assert_equal :base64, block.dig(:source, :type).to_sym
    assert_equal "application/pdf", block.dig(:source, :media_type)
  end

  test "OpenAI inlines a text file rather than silently dropping it" do
    document = attached_document("rows.csv", "text/csv", "a,b\n1,2\n")

    block = CaseDrafter::OpenAI.new(client: :unused).send(:file_block, document)

    assert_equal :input_text, block.fetch(:type).to_sym
    assert_match(/rows\.csv/, block.fetch(:text), "the model must know which table it is reading")
    assert_match(/a,b/, block.fetch(:text))
  end

  test "an unreadable attachment is not claimed to be read" do
    document = attached_document("chart.png", "image/png", "PNG")

    assert_not CaseDrafter.readable?(document)
    assert_nil CaseDrafter::Anthropic.new(client: :unused).send(:document_block, document)
    assert_nil CaseDrafter::OpenAI.new(client: :unused).send(:file_block, document)
  end

  private

  def attached_document(name, content_type, body)
    document = Document.new(case_study: build_case_study, file_name: name, given_at_start: false)
    document.file.attach(io: StringIO.new(body), filename: name, content_type: content_type)
    document.save!
    document
  end

  # OpenAI's strict structured outputs rejects the whole request unless every
  # key in `properties` also appears in `required`; optional means nullable,
  # not absent.
  def assert_strictly_required(node, path = "(root)")
    case node[:type]
    when "object"
      properties = node.fetch(:properties)
      assert_equal properties.keys.map(&:to_s).sort, Array(node[:required]).map(&:to_s).sort,
        "#{path} must require every property it declares"
      properties.each { |name, child| assert_strictly_required(child, "#{path}.#{name}") }
    when "array"
      assert_strictly_required(node.fetch(:items), "#{path}[]")
    end
  end
end
