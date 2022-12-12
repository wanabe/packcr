class Packcr
  class Node
    attr_reader :codes

    attr_accessor :name, :expr, :index, :index, :vars, :capts, :nodes, :code, :neg, :ref, :var, :rule
    attr_accessor :value, :min, :max, :line, :col

    def add_var(var)
      @vars << var
    end

    def add_capt(capt)
      @capts << capt
    end

    def add_node(node)
      @nodes << node
    end

    def add_ref
      @ref += 1
    end

    def initialize
      super
      @codes = []
    end

    def debug_dump(indent = 0)
      # raise "Internal error"
    end

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

    class ReferenceNode < Packcr::Node
      def initialize
        super
        self.var = nil
        self.index = nil
        self.name = nil
        self.rule = nil
        self.line = nil
        self.col = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Reference(var:'#{var || "(null)"}', index:"
        Packcr.dump_integer_value(index)
        $stdout.print ", name:'#{name}', rule:'#{rule&.name || "(null)"}')\n"
      end
    end

    class StringNode < Packcr::Node
      def initialize
        super
        self.value = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}String(value:'"
        Packcr.dump_escaped_string(value)
        $stdout.print "')\n"
      end
    end

    class CharclassNode < Packcr::Node
      def initialize
        super
        self.value = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Charclass(value:'"
        Packcr.dump_escaped_string(value)
        $stdout.print "')\n"
      end
    end

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
    end

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
    end

    class SequenceNode < Packcr::Node
      def initialize
        super
        self.nodes = []
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Sequence(max:#{max}, len:#{nodes.length}) {\n"
        nodes.each do |child_node|
          child_node.debug_dump(indent + 2)
        end
        $stdout.print "#{" " * indent}}\n"
      end

      def max
        m = 1
        m <<= 1 while m < @nodes.length
        m
      end
    end

    class AlternateNode < Packcr::Node
      def initialize
        super
        self.nodes = []
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Alternate(max:#{max}, len:#{nodes.length}) {\n"
        nodes.each do |child_node|
          child_node.debug_dump(indent + 2)
        end
        $stdout.print "#{" " * indent}}\n"
      end

      def max
        m = 1
        m <<= 1 while m < @nodes.length
        m
      end
    end

    class CaptureNode < Packcr::Node
      def initialize
        super
        self.expr = nil
        self.index = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Capture(index:"
        Packcr.dump_integer_value(index)
        $stdout.print ") {\n"
        expr.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}}\n"
      end
    end

    class ExpandNode < Packcr::Node
      def initialize
        super
        self.index = nil
        self.line = nil
        self.col = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Expand(index:"
        Packcr.dump_integer_value(index)
        $stdout.print ")\n"
      end
    end

    class ActionNode < Packcr::Node
      def initialize
        super
        self.code = Packcr::CodeBlock.new
        self.index = nil
        self.vars = []
        self.capts = []
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Action(index:"
        Packcr.dump_integer_value(index)
        $stdout.print ", code:{"
        Packcr.dump_escaped_string(code.text)
        $stdout.print "}, vars:"

        vars = self.vars
        capts = self.capts
        if vars.length + capts.length > 0
          $stdout.print "\n"
          vars.each do |ref|
            $stdout.print "#{" " * (indent + 2)}'#{ref.var}'\n"
          end
          capts.each do |capt|
            $stdout.print "#{" " * (indent + 2)}$#{capt.index + 1}\n"
          end
          $stdout.print "#{" " * indent})\n"
        else
          $stdout.print "none)\n"
        end
      end
    end

    class ErrorNode < Packcr::Node
      def initialize
        super
        self.expr = nil
        self.code = Packcr::CodeBlock.new
        self.index = nil
        self.vars = []
        self.capts = []
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Error(index:"
        Packcr.dump_integer_value(index)
        $stdout.print ", code:{"
        Packcr.dump_escaped_string(code.text)
        $stdout.print "}, vars:\n"
        vars.each do |ref|
          $stdout.print "#{" " * (indent + 2)}'#{ref.var}'\n"
        end
        capts.each do |capt|
          $stdout.print "#{" " * (indent + 2)}$#{capt.index + 1}\n"
        end
        $stdout.print "#{" " * indent}) {\n"
        expr.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}}\n"
      end
    end
  end
end
