module AiProviders
  ToolArgumentsDelta = Data.define(:id, :delta) do
    def initialize(id:, delta:)
      Contract.nonblank_string!(:id, id)
      Contract.string!(:delta, delta)
      super
    end
  end
end
