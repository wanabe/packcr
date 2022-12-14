class Packcr
  class Node
    class QuantityNode < Packcr::Node
      def initialize
        super
        self.min = self.max = 0
        self.expr = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Quantity(min:#{min}, max:#{max}) {\n"
        expr.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}}\n"
      end
    end
  end
end
