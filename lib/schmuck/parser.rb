# frozen_string_literal: true

require "strscan"

module Schmuck
  class Parser
    Accessor  = Data.define(:type, :key, :optional)
    Aggregate = Data.define(:expressions, :optional)

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

    # expression := '?'? ( '*' aggregated | accessor )
    def expression
      optional = !@s.skip("?").nil?
      @s.skip("*") ? Aggregate.new(aggregated, optional) : accessor(optional)
    end

    # aggregated := '(' expression+ ')' | expression
    def aggregated
      return [expression] unless @s.skip("(")

      expressions = [expression]
      expressions << expression until @s.skip(")")
      expressions
    end

    # accessor := '.' ( quoted | word ) | '[' bracket ']'
    def accessor(optional)
      type, key =
        if    @s.skip(".") then [:method, quoted || word]
        elsif @s.skip("[") then bracket.tap { expect("]") }
        else  raise error("expected '.', '[' or '*'")
        end
      Accessor.new(type, key, optional)
    end

    # bracket := ':' word | quoted | digits | word
    def bracket
      if @s.skip(":")                       then [:symbol, word.to_sym]
      elsif (string = quoted)               then [:string, string]
      elsif (digits = @s.scan(/\d+(?=\])/)) then [:index, Integer(digits)]
      else                                       [:property, word]
      end
    end

    def word = @s.scan(/\w+/) || raise(error("expected identifier"))

    # quoted := "'" [^']+ "'" | '"' [^"]+ '"'
    def quoted
      return unless (quote = @s.scan(/['"]/))

      (@s.scan(/[^#{quote}]+/) || raise(error("expected identifier"))).tap { expect(quote) }
    end

    def expect(str) = @s.skip(str) || raise(error("expected #{str.inspect}"))

    def error(message)
      ParseError.new("#{message} at #{@s.pos} in #{@s.string.inspect}")
    end
  end
end
