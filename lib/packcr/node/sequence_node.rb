class Packcr
  class Node
    class SequenceNode < Packcr::Node
      def initialize
        super
        self.nodes = []
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
            if i + 1 < rnodes.length
              gen.write " " * indent
              gen.write "/* unreachable codes omitted */\n"
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
    end
  end
end
