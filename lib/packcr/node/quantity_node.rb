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
            r = nil
            gen.write Packcr.template("node/quantify_many.c.erb", binding, indent: indent)

            if min <= 0
              return Packcr::CODE_REACH__ALWAYS_SUCCEED
            end
            if r == Packcr::CODE_REACH__ALWAYS_FAIL
              return Packcr::CODE_REACH__ALWAYS_FAIL
            end
            return Packcr::CODE_REACH__BOTH
          end
        elsif max == 1
          if min > 0
            return gen.generate_code(expr, onfail, indent, bare)
          else
            gen.generate_block(indent, bare) do |indent|
              gen.write Packcr.template("node/quantify_one.c.erb", binding, indent: indent - 4)
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
