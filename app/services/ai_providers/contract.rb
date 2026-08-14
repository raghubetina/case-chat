module AiProviders
  module Contract
    module_function

    def nonblank_string!(name, value)
      return value if value.is_a?(String) && !value.strip.empty?

      raise ArgumentError, "#{name} must be a nonblank String"
    end

    def optional_nonblank_string!(name, value)
      return value if value.nil?
      return value if value.is_a?(String) && !value.strip.empty?

      raise ArgumentError, "#{name} must be nil or a nonblank String"
    end

    def string!(name, value)
      return value if value.is_a?(String)

      raise ArgumentError, "#{name} must be a String"
    end

    def positive_integer!(name, value)
      return value if value.is_a?(Integer) && value.positive?

      raise ArgumentError, "#{name} must be a positive Integer"
    end

    def nonnegative_integer!(name, value)
      return value if value.is_a?(Integer) && value >= 0

      raise ArgumentError, "#{name} must be a nonnegative Integer"
    end

    def boolean!(name, value)
      return value if value == true || value == false

      raise ArgumentError, "#{name} must be true or false"
    end

    def hash!(name, value)
      raise ArgumentError, "#{name} must be a Hash" unless value.is_a?(Hash)

      deep_copy_and_freeze(value)
    end

    def typed_array!(name, value, type)
      raise ArgumentError, "#{name} must be an Array" unless value.is_a?(Array)
      unless value.all? { |item| item.is_a?(type) }
        raise ArgumentError, "#{name} must contain only #{type.name} values"
      end

      value.dup.freeze
    end

    def deep_copy_and_freeze(value)
      copy = case value
      when Hash
        value.each_with_object({}) do |(key, item), hash|
          hash[deep_copy_and_freeze(key)] = deep_copy_and_freeze(item)
        end
      when Array
        value.map { |item| deep_copy_and_freeze(item) }
      else
        begin
          value.dup
        rescue TypeError
          value
        end
      end

      copy.freeze
    end
  end
end
