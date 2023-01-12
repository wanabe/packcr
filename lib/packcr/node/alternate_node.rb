class Packcr
  class Node
    class AlternateNode < Packcr::Node
      attr_accessor :nodes

      def initialize(*nodes)
        super()
        self.nodes = nodes
      end

      def alt(node)
        @nodes << node if node
        self
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

      def generate_code(gen, onfail, indent, bare, oncut: nil)
        b = false
        m = gen.next_label

        gen.write Packcr.template("node/alternate.#{gen.lang}.erb", binding, indent: indent - 4, unwrap: bare)

        reachability
      end

      def reachability
        reach = Packcr::CODE_REACH__ALWAYS_FAIL
        nodes.each_with_index do |expr, i|
          r = expr.reachability
          if r == Packcr::CODE_REACH__ALWAYS_SUCCEED
            return Packcr::CODE_REACH__ALWAYS_SUCCEED
          elsif r == Packcr::CODE_REACH__BOTH
            reach = Packcr::CODE_REACH__BOTH
          end
        end
        reach
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

      def verify_captures(ctx, capts)
        m = capts.length
        v = capts.dup
        nodes.each do |node|
          v = v[0, m]
          node.verify_captures(ctx, v)
          v[m...-1].each do |added_node|
            capts.push(added_node)
          end
        end
      end

      def link_references(ctx)
        nodes.each do |node|
          node.link_references(ctx)
        end
      end
    end
  end
end
