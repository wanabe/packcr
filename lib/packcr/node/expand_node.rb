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
    end
  end
end
