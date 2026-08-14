module Cases
  class CreateDraft
    def self.call(author:, attributes:)
      new(author:, attributes:).call
    end

    def initialize(author:, attributes:)
      @author = author
      @attributes = attributes.to_h.symbolize_keys.slice(*Case::DRAFT_EDITABLE_ATTRIBUTES)
    end

    def call
      author.authored_cases.build(attributes).tap(&:save)
    end

    private

    attr_reader :author, :attributes
  end
end
