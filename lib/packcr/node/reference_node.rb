class Packcr
  class Node
    class ReferenceNode < Packcr::Node
      attr_accessor :var, :index, :name, :rule, :line, :col

      def initialize(name = nil, var = nil)
        @name = name
        @var = var
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Reference(var:'#{var || "(null)"}', index:"
        Packcr.dump_integer_value(index)
        $stdout.print ", name:'#{name}', rule:'#{rule&.name || "(null)"}')\n"
      end

      def generate_code(gen, onfail, indent, bare)
        gen.write Packcr.template("node/reference.#{gen.lang}.erb", binding, indent: indent)
        Packcr::CODE_REACH__BOTH
      end

      def verify_variables(vars)
        return if index.nil?

        found = vars.any? do |var|
          unless var.is_a?(Packcr::Node::ReferenceNode)
            raise "unexpected var: #{var.class}"
          end
          index == var.index
        end
        vars.push(self) if !found
      end

      def verify_captures(ctx, capts)
      end

      def link_references(ctx)
        rule = ctx.rule(name)
        if !rule
          ctx.error line + 1, col + 1, "No definition of rule '#{name}'"
        else
          unless rule.is_a?(Packcr::Node::RuleNode)
            raise "unexpected node type #{rule.class}"
          end
          rule.add_ref
          self.rule = rule
        end
      end
    end
  end
end
