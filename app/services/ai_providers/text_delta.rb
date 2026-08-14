module AiProviders
  TextDelta = Data.define(:text) do
    def initialize(text:)
      Contract.string!(:text, text)
      super
    end
  end
end
