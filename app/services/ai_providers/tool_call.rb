module AiProviders
  ToolCall = Data.define(:id, :name, :arguments) do
    def initialize(id:, name:, arguments:)
      Contract.nonblank_string!(:id, id)
      Contract.nonblank_string!(:name, name)
      arguments = Contract.hash!(:arguments, arguments)
      super
    end
  end
end
