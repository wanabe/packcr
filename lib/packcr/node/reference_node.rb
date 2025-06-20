class Packcr
  class Node
    class ReferenceNode < Packcr::Node
      attr_accessor :var, :index, :name, :rule, :line, :col

      def initialize(name = nil, var = nil, line = nil, col = nil)
        @name = name
        @var = var
        @line = line
        @col = col
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Reference(var:'#{var || "(null)"}', index:"
        Packcr.dump_integer_value(index)
        $stdout.print ", name:'#{name}', rule:'#{rule&.name || "(null)"}')\n"
      end

      def reversible?(gen)
        gen.lang == :rb
      end

      def generate_code(gen, onfail, indent, unwrap, oncut: nil)
        get_code(gen, onfail, indent, unwrap, oncut)
      end

      def generate_reverse_code(gen, onsuccess, indent, unwrap, oncut: nil)
        get_reverse_code(gen, onsuccess, indent, unwrap, oncut)
      end

      def reachability
        Packcr::CODE_REACH__BOTH
      end

      def setup_rule(rule)
        rule.has_ref = true
        return unless var

        i = rule.vars.index do |ref|
          unless ref.is_a?(Packcr::Node::ReferenceNode)
            raise "Unexpected node type: #{ref.class}"
          end

          var == ref.var
        end
        if !i
          i = rule.vars.length
          rule.vars << self
        end
        @index = i
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

      def link_references(ctx)
        rule = ctx.root.rule(name)
        if rule
          unless rule.is_a?(Packcr::Node::RuleNode)
            raise "unexpected node type #{rule.class}"
          end

          rule.add_ref
          self.rule = rule
        else
          ctx.error line + 1, col + 1, "No definition of rule '#{name}'"
        end
      end

      def to_h
        {
          type: :reference,
          name: name,
          var: var,
        }
      end
    end
  end
end

require "packcr/generated/node/reference_node"
