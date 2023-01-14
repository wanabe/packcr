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

      def generate_code(gen, onfail, indent, bare, oncut: nil)
        n = value&.length || 0
        if n > 0
          if n > 1
            gen.write Packcr.template("node/string_many.#{gen.lang}.erb", binding, indent: indent)
          else
            gen.write Packcr.template("node/string_one.#{gen.lang}.erb", binding, indent: indent)
          end
        end
      end

      def reachability
        n = value&.length || 0
        if n <= 0
          return Packcr::CODE_REACH__ALWAYS_SUCCEED
        end
        Packcr::CODE_REACH__BOTH
      end
    end
  end
end
