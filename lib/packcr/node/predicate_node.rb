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
        r = nil
        if neg
          l = gen.next_label
          r, code = gen.generate_code_str(expr, l, 4, false)
          gen.write Packcr.template("node/predicate_neg.c.erb", binding, indent: indent, unwrap: bare)
          case r
          when Packcr::CODE_REACH__ALWAYS_SUCCEED
            r = Packcr::CODE_REACH__ALWAYS_FAIL
          when Packcr::CODE_REACH__ALWAYS_FAIL
            r = Packcr::CODE_REACH__ALWAYS_SUCCEED
          end
        else
          l = gen.next_label
          m = gen.next_label
          r, code = gen.generate_code_str(expr, l, 4, false)
          gen.write Packcr.template("node/predicate.c.erb", binding, indent: indent, unwrap: bare)
        end
        return r
      end

      def verify_variables(vars)
        expr.verify_variables(vars)
      end
    end
  end
end
