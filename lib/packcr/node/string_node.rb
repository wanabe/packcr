class Packcr
  class Node
    class StringNode < Packcr::Node
      attr_accessor :value

      def initialize(value = nil)
        self.value = value
      end

      def value=(value)
        @value = value&.b
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}String(value:'"
        Packcr.dump_escaped_string(value)
        $stdout.print "')\n"
      end

      def reversible?(gen)
        gen.lang == :rs
      end

      def generate_code(gen, onfail, indent, bare, oncut: nil)
        n = value&.length || 0
        return unless n > 0

        if n > 1
          gen.write Packcr.format_code(get_many_code(gen, onfail, indent, bare, oncut, n), indent: indent)
        else
          gen.write Packcr.format_code(get_one_code(gen, onfail, indent, bare, oncut, n), indent: indent)
        end
      end

      def generate_reverse_code(gen, onsuccess, indent, bare, oncut: nil)
        n = value&.length || 0

        if n > 1
          gen.write Packcr.format_code(get_many_reverse_code(gen, onsuccess, indent, bare, oncut, n), indent: indent)
        else
          gen.write Packcr.format_code(get_one_reverse_code(gen, onsuccess, indent, bare, oncut, n), indent: indent)
        end
      end

      def reachability
        n = value&.length || 0
        if n <= 0
          return Packcr::CODE_REACH__ALWAYS_SUCCEED
        end

        Packcr::CODE_REACH__BOTH
      end

      def to_h
        {
          type: :string,
          value: value,
        }
      end
    end
  end
end

require "packcr/generated/node/string_node"
