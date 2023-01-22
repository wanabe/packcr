class Packcr
  class Node
    class ExpandNode < Packcr::Node
      attr_accessor :index, :line, :col

      def initialize(index = nil, line = nil, col = nil)
        @index = index
        @line = line
        @col = col
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Expand(index:"
        Packcr.dump_integer_value(index)
        $stdout.print ")\n"
      end

      def generate_code(gen, onfail, indent, bare, oncut: nil)
        gen.write Packcr.format_code(get_code(gen, onfail, indent, bare, oncut), indent: indent, unwrap: bare)
      end

      def reachability
        Packcr::CODE_REACH__BOTH
      end

      def verify_captures(ctx, capts)
        found = capts.any? do |capt|
          unless capt.is_a?(Packcr::Node::CaptureNode)
            raise "unexpected capture: #{capt.class}"
          end

          index == capt.index
        end
        return if found || index.nil?

        ctx.error line + 1, col + 1, "Capture #{index + 1} not available at this position"
      end

      def to_h
        {
          type: :expand,
          index: index,
        }
      end
    end
  end
end

require "packcr/generated/node/expand_node"
