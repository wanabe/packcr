class Packcr
  class Node
    class ReferenceNode < Packcr::Node
      def initialize
        super
        self.var = nil
        self.index = nil
        self.name = nil
        self.rule = nil
        self.line = nil
        self.col = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Reference(var:'#{var || "(null)"}', index:"
        Packcr.dump_integer_value(index)
        $stdout.print ", name:'#{name}', rule:'#{rule&.name || "(null)"}')\n"
      end

      def generate_code(gen, onfail, indent, bare)
        gen.write Packcr.template("node/reference.c.erb", binding, indent: indent)
        Packcr::CODE_REACH__BOTH
      end
    end
  end
end
