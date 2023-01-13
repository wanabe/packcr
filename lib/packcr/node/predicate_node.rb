class Packcr
  class Node
    class PredicateNode < Packcr::Node
      attr_accessor :neg, :expr

      def initialize(expr = nil, neg = false)
        super()
        @expr = expr
        @neg = neg
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Predicate(neg:#{neg ? 1 : 0}) {\n"
        expr.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}}\n"
      end

      def generate_code(gen, onfail, indent, bare, oncut: nil)
        r = nil
        if neg
          l = gen.next_label
          code = gen.generate_code_str(expr, l, 4, false)
          r = expr.reachability
          gen.write Packcr.template("node/predicate_neg.#{gen.lang}.erb", binding, indent: indent, unwrap: bare)
        else
          l = gen.next_label
          m = gen.next_label
          code = gen.generate_code_str(expr, l, 4, false)
          r = expr.reachability
          gen.write Packcr.template("node/predicate.#{gen.lang}.erb", binding, indent: indent, unwrap: bare)
        end
      end

      def reachability
        if neg
          -expr.reachability
        else
          expr.reachability
        end
      end

      def verify_variables(vars)
        expr.verify_variables(vars)
      end

      def verify_captures(ctx, capts)
        expr.verify_captures(ctx, capts)
      end

      def link_references(ctx)
        expr.link_references(ctx)
      end

      def nodes
        [expr]
      end
    end
  end
end
