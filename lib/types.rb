require 'types/version'
require 'types/struct'

module Types
  class CastError < StandardError; end
  class DefinitionError < StandardError; end
  class UnknownType < StandardError; end

  DEFINITIONS = {
    any: lambda do |val, _opts|
      val
    end,
    int: lambda do |val, _opts|
      val.is_a?(Integer) && val ||
        fail(CastError, "Integer expected, got #{val.inspect}")
    end,
    float: lambda do |val, _opts|
      val.is_a?(Numeric) && val.to_f ||
        fail(CastError, "Number expected, got #{val.inspect}")
    end,
    string: lambda do |val, _opts|
      val.is_a?(String) && val.to_s ||
        fail(CastError, "String expected, got #{val.inspect}")
    end,
    bool: lambda do |val, _opts|
      if (!!val == val)
        val
      else
        fail(CastError, "Boolean expected, got #{val.inspect}")
      end
    end,
    enum: lambda do |val, opts|
      values = opts[:values]
      unless values.is_a? Array
        fail(
          DefinitionError,
          "Expected an enum to have a list of values, got #{values.inspect}"
        )
      end

      unless val.is_a?(String) || val.is_a?(Symbol)
        fail(CastError, "String or symbol expected, got #{val.inspect}")
      end
      val = val.to_sym

      values.include?(val) && val ||
        fail(
          CastError,
          "Value #{val.inspect} not included in the enum #{values}"
        )
    end,
    date: lambda do |val, _opts|
      case val
      when String
        # Filter out datetimes
        unless val.length == 10
          fail(CastError, "Date, or ISO String expected, got #{val.inspect}")
        end
        Date.parse(val)
      when DateTime
        fail(CastError, "Date, or ISO String expected, got #{val.inspect}")
      when Date
        val.to_date
      else
        fail(CastError, "Date, or ISO String expected, got #{val.inspect}")
      end
    end,
    datetime: lambda do |val, _opts|
      case val
      when String
        DateTime.parse(val)
      when DateTime
        val
      when Date
        val.to_datetime
      else
        fail(
          CastError,
          "Date, DateTime, or ISO String expected, got #{val.inspect}"
        )
      end
    end,
    hash: lambda do |val, _opts|
      fail CastError, "Hash expected" unless val.is_a?(Hash)
      val
    end,
    object: lambda do |val, opts|
      opts[:fields].to_h do |name, type|
        field = val.key?(name) ? val[name] : val[name.to_s]
        [
          name,
          begin
            Types.cast(field, type)
          rescue CastError => e
            raise CastError, "Could not cast field #{name} : #{e.message}"
          end
        ]
      end
    end,
    array: lambda do |val, opts|
      val.map do |elem|
        begin
          Types.cast(elem, opts[:of])
        rescue CastError => e
          raise CastError, "Could not cast element #{elem.inspect} : #{e.message}"
        end
      end
    end,
    struct: ->(val, opts) { opts[:struct].new(val) }
  }

  class << self
    def cast(input, definition)
      # Handle short-hand notation
      definition = { type: definition } if definition.is_a? Symbol
      type = definition[:type]

      if input.nil?
        if definition.key?(:default)
          if definition[:default].respond_to?(:call)
            input = definition[:default].call
          else
            input = definition[:default]
          end
        elsif definition[:nullable]
          return nil
        else
          fail CastError, "Unexpected nil for definition #{definition.inspect}"
        end
      end

      get(type).call(input, definition)
    end

    def register(type, &block)
      if DEFINITIONS[type]
        fail DefinitionError,
             "Type #{type} can not be registered as it is already defined"
      end
      DEFINITIONS[type] = Proc.new(&block)
    end

    def get(type)
      DEFINITIONS[type] ||
        fail(UnknownType, "Could not find type definition for #{type.inspect}")
    end

    alias_method :[], :get
  end
end
