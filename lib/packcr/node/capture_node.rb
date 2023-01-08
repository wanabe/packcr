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
        r = nil
        gen.write Packcr.template("node/capture.#{gen.lang}.erb", binding, indent: indent)
        return r
      end

      def verify_variables(vars)
        expr.verify_variables(vars)
      end

      def verify_captures(ctx, capts)
        expr.verify_captures(ctx, capts)
        capts.push(self)
      end

      def link_references(ctx)
        expr.link_references(ctx)
      end

      def nodes
        [expr]
      end

      def setup_rule(rule)
        @index = rule.capts.length
        rule.capts << self
        super
      end
    end
  end
end
