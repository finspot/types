module Types
  class Struct
    class << self
      def define(definition, &block)
        # Recursively clean definition and define sub structs if needed
        definition =
          definition.to_h { |field, type| [field, clean_definition(type)] }

        # Create the actual instance
        Class.new(self).tap do |struct|
          @@_memo = {}

          # Convert recursively to struct
          definition.keys.each { |field| struct.attr_reader(field) }

          struct.define_singleton_method(:definition) { definition }

          struct.define_method(:initialize) do |data|
            definition.each do |field, type|
              val = data[field] || data[field.to_s]
              instance_variable_set :"@#{field}", Types.cast(val, type)
            end
          end

          struct.class_eval(&block) if block
        end
      end

      private

      def clean_definition(type)
        if type.is_a?(Symbol)
          { type: type }
        elsif type.is_a?(Class) && type < Types::Struct
          { type: :struct, struct: type }
        elsif type[:type] == :array
          type.dup.tap { |t| t[:of] = clean_definition(type[:of]) }
        elsif type[:type] == :object
          struct = define(type[:fields])

          type.dup.tap do |t|
            t[:type] = :struct
            t.delete :fields
            t[:struct] = struct
          end
        else
          type
        end
      end
    end

    def to_h
      self.class.definition.keys.to_h do |key|
        val = send(key)
        if val.is_a?(Array)
          [key, val.map { |elem| elem.respond_to?(:to_h) ? elem.to_h : elem }]
        elsif val.respond_to?(:to_h)
          [key, val.to_h]
        else
          [key, val]
        end
      end
    end
  end
end
