module AiProviders
  Turn = Data.define(:role, :content) do
    def initialize(role:, content:)
      unless role == "user" || role == "assistant"
        raise ArgumentError, "role must be user or assistant"
      end

      Contract.nonblank_string!(:content, content)
      super
    end
  end
end
