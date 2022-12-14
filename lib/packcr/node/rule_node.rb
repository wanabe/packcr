class Packcr
  class Node
    class RuleNode < Packcr::Node
      def initialize
        super
        self.name = nil
        self.expr = nil
        self.ref = 0
        self.vars = []
        self.capts = []
        self.line = nil
        self.col = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Rule(name:'#{name}', ref:#{ref}, vars.len:#{vars.length}, capts.len:#{capts.length}, codes.len:#{codes.length}) {\n"
        expr.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}}\n"
      end
    end
  end
end
