require 'schmuck/version'
require 'schmuck/lexer'
require 'schmuck/path'

module Schmuck
  def self.cache(string)
    return yield if @@cache_max == 0
    value = @@cache[string]

    @@cache.clear if @@cache.size > @@cache_max

    if value.nil?
      value = yield
      @@cache[string] = value if value
    end

    value
  end

  @@cache = {}
  @@cache_max = 10_000
end

class String
  def to_proc
    Schmuck.cache(self) do
      Schmuck::Path.parse(self).to_proc
    end
  end
end
