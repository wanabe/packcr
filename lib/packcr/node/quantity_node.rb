class Packcr
  class Node
    class QuantityNode < Packcr::Node
      def initialize
        super
        self.min = self.max = 0
        self.expr = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Quantity(min:#{min}, max:#{max}) {\n"
        expr.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}}\n"
      end

      def generate_code(gen, onfail, indent, bare)
        if max > 1 || max < 0
          gen.generate_block(indent, bare) do |indent|
            gen.write Packcr.template("node/quantify_many1.c.erb", binding, indent: indent)
            l = gen.next_label
            r = gen.generate_code(expr, l, indent + 4, false)
            gen.write Packcr.template("node/quantify_many2.c.erb", binding, indent: indent)

            if min > 0
              if r == Packcr::CODE_REACH__ALWAYS_FAIL
                return Packcr::CODE_REACH__ALWAYS_FAIL
              else
                return Packcr::CODE_REACH__BOTH
              end
            else
              return Packcr::CODE_REACH__ALWAYS_SUCCEED
            end
          end
        elsif max == 1
          if min > 0
            return gen.generate_code(expr, onfail, indent, bare)
          else
            gen.generate_block(indent, bare) do |indent|
              gen.write(<<~EOS.gsub(/^/, " " * indent))
                const size_t p = ctx->cur;
                const size_t n = chunk->thunks.len;
              EOS
              l = gen.next_label
              if gen.generate_code(expr, l, indent, false) != Packcr::CODE_REACH__ALWAYS_SUCCEED
                m = gen.next_label
                gen.write Packcr.template("node/quantify_one.c.erb", binding, indent: indent)
              end
            end
            return Packcr::CODE_REACH__ALWAYS_SUCCEED
          end
        else
          # no code to generate
          return Packcr::CODE_REACH__ALWAYS_SUCCEED
        end
      end
    end
  end
end
