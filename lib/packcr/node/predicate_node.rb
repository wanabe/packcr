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
        if neg
          gen.write Packcr.template("node/predicate_neg.#{gen.lang}.erb", binding, indent: indent, unwrap: bare)
        else
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

      def nodes
        [expr]
      end
    end
  end
end
