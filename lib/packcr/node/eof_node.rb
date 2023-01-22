class Packcr
  class Node
    class EofNode < Packcr::Node
      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Eof()\n"
      end

      def generate_code(gen, onfail, indent, bare, oncut: nil)
        gen.write Packcr.format_code(get_code(gen, onfail, indent, bare, oncut), indent: indent, unwrap: bare)
      end

      def reachability
        Packcr::CODE_REACH__BOTH
      end

      def to_h
        {
          type: :eof,
        }
      end
    end
  end
end

require "packcr/generated/node/eof_node"
