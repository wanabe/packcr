class Packcr
  class Node
    class SequenceNode < Packcr::Node
      attr_accessor :nodes

      def initialize(*nodes)
        super()
        self.nodes = nodes
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Sequence(max:#{max}, len:#{nodes.length}) {\n"
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
        nodes.each_with_index do |expr, i|
          case gen.generate_code(expr, onfail, indent, false)
          when Packcr::CODE_REACH__ALWAYS_FAIL
            if i + 1 < nodes.length
              gen.write Packcr.template("node/sequence_unreachable.#{gen.lang}.erb", binding, indent: indent)
            end
            return Packcr::CODE_REACH__ALWAYS_FAIL
          when Packcr::CODE_REACH__ALWAYS_SUCCEED
          else
            b = true
          end
        end
        return b ? Packcr::CODE_REACH__BOTH : Packcr::CODE_REACH__ALWAYS_SUCCEED
      end

      def verify_variables(vars)
        nodes.each do |node|
          node.verify_variables(vars)
        end
      end

      def verify_captures(ctx, capts)
        nodes.each do |node|
          node.verify_captures(ctx, capts)
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
