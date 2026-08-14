module Cases
  class InvalidConfiguration < StandardError
    attr_reader :readiness

    def initialize(readiness)
      @readiness = readiness
      super("Case cannot be published: #{problems.map(&:key).to_sentence}")
    end

    def problems
      readiness.problems
    end
  end
end
