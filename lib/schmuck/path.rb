module Schmuck
  class Path
    class BasePart
      attr_reader :key
      attr_accessor :mandatory

      def initialize(key)
        @key = key
      end

      def apply(object)
        raise NotImplementedError
      end
    end

    class MethodPart < BasePart
      def initialize(key)
        super(key.to_sym)
      end

      def apply(object)
        object.public_send(key)
      end
    end

    class BracketsPart < BasePart
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

    class ArrayIndexPart < BracketsPart
      def initialize(key)
        super(Integer(key))
      end
    end

    class IndexPart < BasePart
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

    PART_TYPES = {
      method: MethodPart,
      symbol: SymbolPart,
      string: StringPart,
      array_index: ArrayIndexPart,
      index: IndexPart,
    }.freeze

    def self.parse(string)
      tokens = Lexer.new(string).lexify
      parts = tokens.map do |token|
        part = PART_TYPES[token[:type]].new(token[:lexeme])
        part.mandatory = token[:mandatory]
        part
      end
      new(parts)
    end

    def initialize(parts)
      @parts = parts
    end

    def apply(object)
      @parts.inject(object) do |object, part|
        if part.mandatory
          part.apply(object)
        else
          part.apply(object) if object !=  nil
        end
      end
    end

    def to_proc
      -> (receiver) { apply(receiver) }
    end
  end
end
