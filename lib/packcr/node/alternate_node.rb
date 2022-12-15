class Packcr
  class Node
    class AlternateNode < Packcr::Node
      def initialize
        super
        self.nodes = []
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Alternate(max:#{max}, len:#{nodes.length}) {\n"
        nodes.each do |node|
          node.debug_dump(indent + 2)
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

      def verify_variables(vars)
        m = vars.length
        v = vars.dup
        nodes.each do |node|
          v = v[0, m]
          node.verify_variables(v)
          v[m...-1].each do |added_node|
            found = vars[m...-1].any? do |added_var|
              added_node.index == added_var.index
            end
            if !found
              vars.push(added_node)
            end
          end
        end
      end
    end
  end
end
