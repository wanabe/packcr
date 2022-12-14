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
        gen.generate_block(indent, bare) do |indent|
          gen.write(<<~EOS.gsub(/^/, " " * indent))
            const size_t p = ctx->cur;
            size_t q;
          EOS
          r = gen.generate_code(expr, onfail, indent, false)
          gen.write(<<~EOS.gsub(/^/, " " * indent))
            q = ctx->cur;
            chunk->capts.buf[#{index}].range.start = p;
            chunk->capts.buf[#{index}].range.end = q;
          EOS
          return r
        end
      end
    end
  end
end
