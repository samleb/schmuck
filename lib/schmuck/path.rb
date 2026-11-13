# frozen_string_literal: true

module Schmuck
  class Path
    class AccessorPart
      attr_reader :key
      attr_accessor :optional

      def initialize(key)
        @key = key
      end

      def apply(object)
        raise NotImplementedError
      end
    end

    class MethodPart < AccessorPart
      def initialize(key)
        super(key.to_sym)
      end

      def apply(object)
        object.public_send(key)
      end
    end

    class BracketsPart < AccessorPart
      def apply(object)
        object[key]
      end
    end

    class SymbolPart < BracketsPart
      def initialize(key)
        super(key.to_sym)
      end
    end

    class StringPart < BracketsPart
    end

    class IndexPart < BracketsPart
      def initialize(key)
        super(Integer(key))
      end
    end

    class PropertyPart < AccessorPart
      def apply(object)
        # Does this object quack like a hash?
        if object.respond_to?(:key?)
          if object.key?(key)
            object[key]
          elsif object.key?(symbolized_key)
            object[symbolized_key]
          end
        # Poor man's version of key detection
        else
          result = object[key]
          result = object[symbolized_key] if result.nil?
          result
        end
      end

      def symbolized_key
        @symbolized_key ||= key.to_sym
      end
    end

    class AggregatePart
      attr_accessor :optional

      def initialize(path)
        @path = path
      end

      def apply(object)
        case object
        when nil
          raise ArgumentError, "object isn't optional" unless optional
        when Enumerable
          object.map { |element| @path.apply(element) }
        else
          raise ArgumentError, "object isn't Enumerable" unless Enumerable === object
        end
      end
    end

    ACCESSOR_PART_TYPES = {
      method: MethodPart,
      symbol: SymbolPart,
      string: StringPart,
      index: IndexPart,
      property: PropertyPart,
    }.freeze

    def self.parse(string)
      expressions = Parser.parse(string)
      construct(expressions)
    end

    def self.construct(expressions)
      parts = expressions.map do |expression|
        case expression
        when Parser::Aggregate
          AggregatePart.new(construct(expression.expressions)).tap do |part|
            part.optional = expression.optional
          end
        when Parser::Accessor
          ACCESSOR_PART_TYPES[expression.type].new(expression.key).tap do |part|
            part.optional = expression.optional
          end
        end
      end
      new(parts)
    end

    def initialize(parts)
      @parts = parts
    end

    def apply(object)
      @parts.inject(object) do |object, part|
        part.apply(object) unless part.optional && object.nil?
      end
    end

    def to_proc
      -> (receiver) { apply(receiver) }
    end
  end
end
