# require "schmuck/version"
require 'strscan'

module Schmuck
  class Lexer
    PATTERN = /
      # e.g. `.save_the_world`
      (\.(?<mandatory>\!?)(?<method>\w+))
      |

      # e.g. `[:oh_my_gad]``
      ((?<mandatory>\!?)\[:(?<symbol>\w+)\])
      |

      # e.g. `['simple string']`, `["double string"]`
      ((?<mandatory>\!?)\[
        (?<quote>['"])
          (?<string>\w+)
        \g<quote>
       \])
      |

      # e.g. `[42]`
      ((?<mandatory>\!?)\[(?<array_index>\d+)\])
      |

      # e.g. `[foo]`
      ((?<mandatory>\!?)\[(?<index>\w+)\])
    /x

    TYPES = %I( method symbol string array_index index ).freeze

    def initialize(input)
      @input = input
    end

    def lexify
      scanner = StringScanner.new(@input)
      result = []

      loop do
        lexeme = scanner.scan(PATTERN)

        if lexeme.nil?
          if scanner.eos?
            return result
          else
            raise ArgumentError, "lexer error at position #{scanner.pos}"
          end
        end

        TYPES.each do |type|
          lexeme = scanner[type]
          if lexeme
            result << {
              type: type,
              lexeme: lexeme,
              string: scanner.matched,
              mandatory: !!scanner[:mandatory],
            }
            break
          end
        end
      end

      result
    end
  end

  class Path
    class AbstractPart
      attr_reader :key
      attr_accessor :mandatory

      def initialize(key)
        @key = key
      end

      def apply(object)
        raise NotImplementedError
      end
    end

    class MethodPart < AbstractPart
      def initialize(key)
        super(key.to_sym)
      end

      def apply(object)
        object.public_send(key)
      end
    end

    # class BracketsPart < AbstractPart
    #   def apply(object)
    #     object[key]
    #   end
    # end
    #
    # class SymbolPart < BracketsPart
    #   def initialize(key)
    #     super(key.to_sym)
    #   end
    # end
    #
    # class StringPart < BracketsPart
    # end
    #
    # class ArrayIndexPart < BracketsPart
    #   def initialize(key)
    #     super(Integer(key))
    #   end
    # end

    module Bracketable
      def apply(object)
        object[key]
      end
    end

    class SymbolPart < AbstractPart
      include Bracketable

      def initialize(key)
        key.to_sym
      end
    end

    class IndexPart < AbstractPart
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
      p tokens
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
        # if object != nil
        #   part.apply(object)
        # end

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

  def self.cache(string)
    return yield if @@cache_max = 0
    value = @@cache[string]

    @@cache.clear if @@cache.size > @@cache_max

    if value.nil?
      value = yield
      @@cache[string] = value if value
    end

    value
  end

  @@cache = {}
  @@cache_max = 200
end


hashes = (1..10).map do |n|
  {
    integer: n,
    float: n.to_f,
    double: n * 2,
    square: n ** 2,
    multiples: [n * 2, n * 3, n * 4]
  }
end

hashes << {
  integer: 42
}

class String
  def to_proc
    Schmuck.cache(self) do
      Schmuck::Path.parse(self).to_proc
    end
  end
end


require 'pp'
pp hashes.map(&'[multiples][1]')
