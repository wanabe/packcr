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
    end
  end
end
