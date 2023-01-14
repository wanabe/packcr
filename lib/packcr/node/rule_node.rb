class Packcr
  class Node
    class RuleNode < Packcr::Node
      attr_accessor :codes, :name, :expr, :ref, :vars, :capts, :line, :col, :top

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

      def generate_code(gen, onfail, indent, bare, oncut: nil)
        gen.write Packcr.template("node/rule.#{gen.lang}.erb", binding, indent: indent, unwrap: bare)
      end

      def reachability
        expr.reachability
      end

      def verify(ctx)
        expr.verify_variables([])
        expr.verify_captures(ctx, [])
        verify_rule_reference(ctx)
      end

      def verify_rule_reference(ctx)
        return if top
        if ref == 0
          ctx.error line + 1, col + 1, "Never used rule '#{name}'"
        end
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
