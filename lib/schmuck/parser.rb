require "strscan"

module Schmuck
  class Parser
    Accessor  = Data.define(:type, :key, :mandatory)
    Aggregate = Data.define(:expressions, :mandatory)

    class ParseError < StandardError; end

    def self.parse(source) = new(source).parse

    def initialize(source)
      @s = StringScanner.new(source)
    end

    # path := expression+
    def parse
      expressions = [expression]
      expressions << expression until @s.eos?
      expressions
    end

    private

    # expression := '!'? ( '*' aggregated | accessor )
    def expression
      mandatory = !@s.skip("!").nil?
      @s.skip("*") ? Aggregate.new(aggregated, mandatory) : accessor(mandatory)
    end

    # aggregated := '(' expression+ ')' | expression
    def aggregated
      return [expression] unless @s.skip("(")

      expressions = [expression]
      expressions << expression until @s.skip(")")
      expressions
    end

    # accessor := '.' word | '[' bracket ']'
    def accessor(mandatory)
      type, key =
        if    @s.skip(".") then [:method, word]
        elsif @s.skip("[") then bracket.tap { expect("]") }
        else  raise error("expected '.', '[' or '*'")
        end
      Accessor.new(type, key, mandatory)
    end

    # bracket := ':' word | quote word quote | digits | word
    def bracket
      if @s.skip(":")                       then [:symbol, word.to_sym]
      elsif (quote = @s.scan(/['"]/))       then [:string, word.tap { expect(quote) }]
      elsif (digits = @s.scan(/\d+(?=\])/)) then [:index, Integer(digits)]
      else                                       [:property, word]
      end
    end

    def word = @s.scan(/\w+/) || raise(error("expected identifier"))

    def expect(str) = @s.skip(str) || raise(error("expected #{str.inspect}"))

    def error(message)
      ParseError.new("#{message} at #{@s.pos} in #{@s.string.inspect}")
    end
  end
end
