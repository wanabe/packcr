class Packcr
  class Node
    class CaptureNode < Packcr::Node
      def initialize
        super
        self.expr = nil
        self.index = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Capture(index:"
        Packcr.dump_integer_value(index)
        $stdout.print ") {\n"
        expr.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}}\n"
      end

      def generate_code(gen, onfail, indent, bare)
        r = nil
        gen.write Packcr.template("node/capture.c.erb", binding, indent: indent)
        return r
      end

      def verify_variables(vars)
        expr.verify_variables(vars)
      end

      def verify_captures(ctx, capts)
        expr.verify_captures(ctx, capts)
        capts.push(self)
      end
    end
  end
end
