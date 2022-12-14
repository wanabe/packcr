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
    end
  end
end
