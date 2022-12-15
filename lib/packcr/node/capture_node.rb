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
        gen.generate_block(indent, bare) do |indent|
          gen.write Packcr.template("node/capture.c.erb", binding, indent: indent)
        end
        return r
      end
    end
  end
end
