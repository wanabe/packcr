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
        gen.write Packcr.template("node/capture.#{gen.lang}.erb", binding, indent: indent)
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
    end
  end
end
