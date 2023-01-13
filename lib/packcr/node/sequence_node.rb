class Packcr
  class Node
    class SequenceNode < Packcr::Node
      attr_accessor :nodes

      def initialize(*nodes, cut: false)
        super()
        self.nodes = nodes
        @cut = cut
      end

      def sequence?
        true
      end

      def seq(node, cut: false)
        if node&.sequence?
          node.nodes.each do |child|
            seq(child, cut: cut)
            cut = false
          end
          return self
        end

        if cut
          if node
            node = Packcr::Node::SequenceNode.new(node, cut: true)
          else
            node = Packcr::Node::SequenceNode.new(cut: true)
          end
        end
        if node
          if @nodes.last.sequence?
            @nodes.last.seq(node)
          else
            @nodes << node
          end
        end
        self
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Sequence(max:#{max}, len:#{nodes.length}#{@cut ? ", cut: true" : ""}) {\n"
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

      def generate_code(gen, onfail, indent, bare, oncut: nil)
        if @cut && oncut
          onfail = oncut
        end
        nodes.each_with_index do |expr, i|
          gen.write gen.generate_code_str(expr, onfail, indent, false, oncut: oncut)
          if expr.reachability == Packcr::CODE_REACH__ALWAYS_FAIL
            if i + 1 < nodes.length
              gen.write Packcr.template("node/sequence_unreachable.#{gen.lang}.erb", binding, indent: indent)
            end
            return
          end
        end
      end

      def reachability
        r = Packcr::CODE_REACH__ALWAYS_SUCCEED
        nodes.each do |expr|
          case expr.reachability
          when Packcr::CODE_REACH__ALWAYS_FAIL
            return Packcr::CODE_REACH__ALWAYS_FAIL
          when Packcr::CODE_REACH__BOTH
            r = Packcr::CODE_REACH__BOTH
          end
        end
        r
      end

      def verify_variables(vars)
        nodes.each do |node|
          node.verify_variables(vars)
        end
      end

      def verify_captures(ctx, capts)
        nodes.each do |node|
          node.verify_captures(ctx, capts)
        end
      end

      def link_references(ctx)
        nodes.each do |node|
          node.link_references(ctx)
        end
      end
    end
  end
end
