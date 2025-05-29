class Packcr
  class Node
    class CaptureNode < Packcr::Node
      attr_accessor :expr, :index

      def initialize(expr = nil)
        @expr = expr
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Capture(index:"
        Packcr.dump_integer_value(index)
        $stdout.print ") {\n"
        expr.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}}\n"
      end

      def generate_code(gen, onfail, indent, bare, oncut: nil)
        Packcr.format_code(get_code(gen, onfail, indent, bare, oncut), indent: indent)
      end

      def reachability
        expr.reachability
      end

      def verify_captures(ctx, capts)
        super
        capts.push(self)
      end

      def nodes
        [expr]
      end

      def setup_rule(rule)
        @index = rule.capts.length
        rule.capts << self
      end

      def to_h
        {
          type: :capture,
          expr: expr&.to_h,
        }
      end
    end
  end
end

require "packcr/generated/node/capture_node"
