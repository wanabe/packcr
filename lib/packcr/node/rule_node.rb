class Packcr
  class Node
    class RuleNode < Packcr::Node
      attr_accessor :codes, :name, :expr, :ref, :vars, :capts, :line, :col

      def initialize
        super
        self.name = nil
        self.expr = nil
        self.ref = 0
        self.vars = []
        self.capts = []
        self.line = nil
        self.col = nil
        self.codes = []
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
    end
  end
end
