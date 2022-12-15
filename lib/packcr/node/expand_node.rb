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

      def generate_code(gen, onfail, indent, bare)
        gen.write Packcr.template("node/expand.c.erb", binding, indent: indent, unwrap: bare)
        return Packcr::CODE_REACH__BOTH
      end

      def verify_variables(vars)
      end

      def verify_captures(ctx, capts)
        found = capts.any? do |capt|
          unless capt.is_a?(Packcr::Node::CaptureNode)
            raise "unexpected capture: #{capt.class}"
          end
          index == capt.index
        end
        if !found && index != nil
          ctx.error line + 1, col + 1, "Capture #{index + 1} not available at this position"
        end
      end
    end
  end
end
