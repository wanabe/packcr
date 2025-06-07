class Packcr
  class Node
    class ErrorNode < Packcr::Node
      attr_accessor :expr, :action

      def initialize(expr, action)
        super()
        @expr = expr
        @action = action
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Error(action: #{@action}) {\n"
        $stdout.print "#{" " * (indent + 2)}Action: "
        action.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}) {\n"
        expr.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}}\n"
      end

      def generate_code(gen, onfail, indent, unwrap, oncut: nil)
        get_code(gen, onfail, indent, unwrap, oncut)
      end

      def reachability
        expr.reachability
      end

      def nodes
        [expr, action]
      end

      def index
        action.index
      end

      def vars
        action.vars
      end

      def capts
        action.capts
      end

      def to_h
        {
          type: :error,
          action: action&.to_h,
        }
      end
    end
  end
end

require "packcr/generated/node/error_node"
