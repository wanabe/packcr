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

      def generate_code(gen, onfail, indent, unwrap, oncut: nil)
        if neg
          get_neg_code(gen, onfail, indent, unwrap, oncut)
        else
          get_code(gen, onfail, indent, unwrap, oncut)
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

      def to_h
        {
          type: :predicate,
          expr: expr&.to_h,
          neg: neg,
        }
      end
    end
  end
end

require "packcr/generated/node/predicate_node"
