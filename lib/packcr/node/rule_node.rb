class Packcr
  class Node
    class RuleNode < Packcr::Node
      attr_accessor :codes, :name, :expr, :ref, :vars, :capts, :line, :col

      def initialize(expr = nil, name = nil, line = nil, col = nil)
        super()
        self.ref = 0
        self.vars = []
        self.capts = []
        self.codes = []
        @expr = expr
        @name = name
        @line = line
        @col = col
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Rule(name:'#{name}', ref:#{ref}, vars.len:#{vars.length}, capts.len:#{capts.length}, codes.len:#{codes.length}) {\n"
        expr.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}}\n"
      end

      def verify(ctx)
        expr.verify_variables([])
        expr.verify_captures(ctx, [])
      end

      def add_ref
        @ref += 1
      end

      def setup
        setup_rule(self)
      end

      def nodes
        [expr]
      end
    end
  end
end
