class Packcr
  class Node
    class StringNode < Packcr::Node
      def initialize
        super
        self.value = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}String(value:'"
        Packcr.dump_escaped_string(value)
        $stdout.print "')\n"
      end

      def generate_code(gen, onfail, indent, bare)
        n = value&.length || 0
        if n > 0
          if n > 1
            gen.write Packcr.template("node/string_many.c.erb", binding, indent: indent)
            return Packcr::CODE_REACH__BOTH
          else
            gen.write Packcr.template("node/string_one.c.erb", binding, indent: indent)
            return Packcr::CODE_REACH__BOTH
          end
        else
          # no code to generate
          return Packcr::CODE_REACH__ALWAYS_SUCCEED
        end
        Packcr::CODE_REACH__BOTH
      end
    end
  end
end
