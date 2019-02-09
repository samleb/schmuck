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
end
