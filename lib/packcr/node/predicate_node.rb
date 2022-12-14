class Packcr
  class Node
    class PredicateNode < Packcr::Node
      def initialize
        super
        self.neg = false
        self.expr = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Predicate(neg:#{neg ? 1 : 0}) {\n"
        expr.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}}\n"
      end

      def generate_code(gen, onfail, indent, bare)
        gen.generate_block(indent, bare) do |indent|
          gen.write(<<~EOS.gsub(/^/, " " * indent))
            const size_t p = ctx->cur;
          EOS

          if neg
            l = gen.next_label
            r = gen.generate_code(expr, l, indent, false)

            gen.write Packcr.template("node/predicate_neg.c.erb", binding, indent: indent - 4)

            case r
            when Packcr::CODE_REACH__ALWAYS_SUCCEED
              r = Packcr::CODE_REACH__ALWAYS_FAIL
            when Packcr::CODE_REACH__ALWAYS_FAIL
              r = Packcr::CODE_REACH__ALWAYS_SUCCEED
            end
          else
            l = gen.next_label
            m = gen.next_label
            r = gen.generate_code(expr, l, indent, false)
            gen.write Packcr.template("node/predicate.c.erb", binding, indent: indent - 4)
          end
          return r
        end
      end
    end
  end
end
