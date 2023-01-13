class Packcr
  class Node
    class EofNode < Packcr::Node
      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Eof()\n"
      end

      def generate_code(gen, onfail, indent, bare, oncut: nil)
        gen.write Packcr.template("node/eof.#{gen.lang}.erb", binding, indent: indent, unwrap: bare)
      end

      def reachability
        return Packcr::CODE_REACH__BOTH
      end
    end
  end
end
