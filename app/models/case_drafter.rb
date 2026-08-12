# Drafting a case from the documents an instructor already has.
#
# A teaching case usually exists as a PDF long before it exists as a Case Chat
# case. This reads that material and proposes the structure: the background a
# student is handed, the assignment, the cast, and — the part that carries the
# pedagogy — who introduces whom, and on what cue.
#
# It proposes. Nothing is created until an author reviews it, because a drafted
# system prompt is a guess about what a person withholds, and withholding is
# the whole design of a case.
module CaseDrafter
  Draft = Data.define(:title, :course, :background, :assignment, :contacts, :referrals, :share_rules, :notes) do
    def initialize(title:, course: nil, background: nil, assignment: nil,
      contacts: [], referrals: [], share_rules: [], notes: [])
      super
    end
  end

  DraftedContact = Data.define(:full_name, :role_title, :description, :system_prompt, :in_starting_directory)
  DraftedReferral = Data.define(:from_name, :to_name, :condition)
  DraftedShareRule = Data.define(:contact_name, :file_name, :condition)

  class Error < StandardError; end

  # A draft is proposed, reviewed, and only then applied, so it has to survive
  # between two requests. It goes to the cache rather than the session cookie:
  # a real draft is several KB and would silently overflow the 4KB cookie.
  # Serializing to the same shape Parser reads means one representation, not
  # two that can drift.
  def self.serialize(draft)
    {
      "title" => draft.title, "course" => draft.course,
      "background" => draft.background, "assignment" => draft.assignment,
      "notes" => draft.notes,
      "contacts" => draft.contacts.map { |c|
        {
          "full_name" => c.full_name, "role_title" => c.role_title,
          "description" => c.description, "system_prompt" => c.system_prompt,
          "in_starting_directory" => c.in_starting_directory
        }
      },
      "referrals" => draft.referrals.map { |r|
        {"from_name" => r.from_name, "to_name" => r.to_name, "condition" => r.condition}
      },
      "share_rules" => draft.share_rules.map { |s|
        {"contact_name" => s.contact_name, "file_name" => s.file_name, "condition" => s.condition}
      }
    }
  end

  def self.deserialize(payload) = Parser.call(payload)

  ADAPTERS = {
    "anthropic" => -> { Anthropic.new },
    "openai" => -> { OpenAI.new },
    "fake" => -> { Fake.new }
  }.freeze

  class << self
    attr_writer :current

    def current
      @current ||= ADAPTERS.fetch(Responder.configured_name) { ADAPTERS.fetch("fake") }.call
    end

    def reset! = @current = nil
  end
end
