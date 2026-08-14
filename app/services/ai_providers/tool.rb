module AiProviders
  Tool = Data.define(:name, :description, :input_schema) do
    def initialize(name:, description:, input_schema:)
      Contract.nonblank_string!(:name, name)
      Contract.nonblank_string!(:description, description)
      input_schema = Contract.hash!(:input_schema, input_schema)
      super
    end
  end
end
