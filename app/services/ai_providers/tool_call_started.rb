module AiProviders
  ToolCallStarted = Data.define(:id, :name) do
    def initialize(id:, name:)
      Contract.nonblank_string!(:id, id)
      Contract.nonblank_string!(:name, name)
      super
    end
  end
end
