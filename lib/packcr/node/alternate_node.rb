class Packcr
  class Node
    class AlternateNode < Packcr::Node
      def initialize
        super
        self.nodes = []
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Alternate(max:#{max}, len:#{nodes.length}) {\n"
        nodes.each do |child_node|
          child_node.debug_dump(indent + 2)
        end
        $stdout.print "#{" " * indent}}\n"
      end

      def max
        m = 1
        m <<= 1 while m < @nodes.length
        m
      end

      def generate_code(gen, onfail, indent, bare)
        b = false
        m = gen.next_label

        reach = nil
        gen.write Packcr.template("node/alternate.c.erb", binding, indent: indent - 4, unwrap: bare)

        reach || Packcr::CODE_REACH__ALWAYS_FAIL
      end
    end
  end
end
