class Packcr
  class Node
    class QuantityNode < Packcr::Node
      attr_accessor :min, :max, :expr

      def initialize(expr = nil, min = 0, max = 0)
        super()
        @expr = expr
        @min = min
        @max = max
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Quantity(min:#{min}, max:#{max}) {\n"
        expr.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}}\n"
      end

      def generate_code(gen, onfail, indent, unwrap, oncut: nil)
        if max > 1 || max < 0
          get_many_code(gen, onfail, indent, unwrap, oncut)
        elsif max == 1
          if min > 0
            gen.generate_code(expr, onfail, indent, unwrap, oncut: oncut)
          else
            get_one_code(gen, onfail, indent, unwrap, oncut)
          end
        end
      end

      def reachability
        if max > 1 || max < 0
          if min <= 0
            return Packcr::CODE_REACH__ALWAYS_SUCCEED
          end
          if expr.reachability == Packcr::CODE_REACH__ALWAYS_FAIL
            return Packcr::CODE_REACH__ALWAYS_FAIL
          end

          Packcr::CODE_REACH__BOTH
        elsif max == 1
          return expr.reachability if min > 0

          Packcr::CODE_REACH__ALWAYS_SUCCEED

        else
          Packcr::CODE_REACH__ALWAYS_SUCCEED
        end
      end

      def nodes
        [expr]
      end

      def to_h
        {
          type: :predicate,
          expr: expr&.to_h,
          min: min,
          max: max,
        }
      end
    end
  end
end

require "packcr/generated/node/quantity_node"
