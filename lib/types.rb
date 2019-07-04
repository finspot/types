require 'types/version'
require 'types/struct'

module Types
  class CastError < StandardError; end
  class DefinitionError < StandardError; end
  class UnknownType < StandardError; end

  DEFINITIONS = {
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
        fail(CastError, "Value #{val} not included in the enum #{values}")
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
    object: lambda do |val, opts|
      opts[:fields].to_h { |name, type| [name, Types.cast(val[name], type)] }
    end,
    array: ->(val, opts) { val.map { |elem| Types.cast(elem, opts[:of]) } },
    struct: ->(val, opts) { opts[:struct].new(val) }
  }

  class << self
    def cast(input, definition)
      # Handle short-hand notation
      definition = { type: definition } if definition.is_a? Symbol
      type = definition[:type]

      # Handle nils
      if input.nil?
        if definition[:default]
          return definition[:default]
        elsif definition[:nullable]
          return nil
        else
          fail CastError, 'Unexpected nil'
        end
      end

      get(type).call(input, definition)
    rescue CastError => e
      fail CastError,
           "Could not cast #{input.inspect} to type #{type} : #{e.message}"
    end

    def alias(type, definition = nil)
      fail DefinitionError, "Type #{type} can not be aliased as it is already defined" if DEFINITIONS[type]
      DEFINITIONS[type] = lambda do |val, _opts|
        Types.cast(val, definition)
      end
    end

    def register(type, &block)
      fail DefinitionError, "Type #{type} can not be registered as it is already defined" if DEFINITIONS[type]
      DEFINITIONS[type] = lambda(&block)
    end

    def get(type)
      DEFINITIONS[type] ||
        fail(UnknownType, "Could not find type definition for #{type}")
    end

    alias_method :[], :get
  end
end
