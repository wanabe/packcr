class Packcr
  class Node
    class ErrorNode < Packcr::Node
      attr_accessor :expr, :code, :index, :vars, :capts

      def initialize(expr = nil, code = nil, index = nil)
        super()
        @expr = expr
        @code = code
        @index = index
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

      def generate_code(gen, onfail, indent, bare, oncut: nil)
        Packcr.format_code(get_code(gen, onfail, indent, bare, oncut), indent: indent, unwrap: bare)
      end

      def reachability
        expr.reachability
      end

      def verify_variables(vars)
        @vars = vars
        super
      end

      def verify_captures(ctx, capts)
        @capts = capts
        super
      end

      def nodes
        [expr]
      end

      def setup_rule(rule)
        @index = rule.codes.length
        rule.codes.push(self)
      end

      def to_h
        {
          type: :error,
          code: code&.text,
          vars: vars&.map(&:to_h),
          capts: capts&.map(&:to_h),
          index: @index,
        }
      end
    end
  end
end

require "packcr/generated/node/error_node"
