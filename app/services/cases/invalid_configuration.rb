module Cases
  class InvalidConfiguration < StandardError
    attr_reader :problems

    def initialize(problems)
      @problems = problems
      super("Case cannot be published: #{problems.to_sentence}")
    end
  end
end
