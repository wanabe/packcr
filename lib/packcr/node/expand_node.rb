class Packcr
  class Node
    class ExpandNode < Packcr::Node
      def initialize
        super
        self.index = nil
        self.line = nil
        self.col = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Expand(index:"
        Packcr.dump_integer_value(index)
        $stdout.print ")\n"
      end

      def generate_code(gen, onfail, indent, bare)
        gen.write Packcr.template("node/expand.c.erb", binding, indent: indent, unwrap: bare)
        return Packcr::CODE_REACH__BOTH
      end

      def verify_variables(vars)
      end
    end
  end
end
