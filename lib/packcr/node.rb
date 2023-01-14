class Packcr
  class Node
    def seq(expr, cut: false)
      SequenceNode.new(self).seq(expr, cut: cut)
    end

    def alt(expr)
      AlternateNode.new(self).alt(expr)
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
    end

    def setup_rule(rule)
    end

    def setup(ctx, rule)
      setup_rule(rule)
      link_references(ctx)

      nodes.each do |node|
        node.setup(ctx, rule)
      end
    end

    def nodes
      []
    end

    def reversible?(gen)
      false
    end

    def sequence?
      false
    end
  end
end

require "packcr/node/root_node"
require "packcr/node/rule_node"
require "packcr/node/reference_node"
require "packcr/node/string_node"
require "packcr/node/charclass_node"
require "packcr/node/quantity_node"
require "packcr/node/predicate_node"
require "packcr/node/sequence_node"
require "packcr/node/alternate_node"
require "packcr/node/capture_node"
require "packcr/node/expand_node"
require "packcr/node/action_node"
require "packcr/node/error_node"
require "packcr/node/eof_node"
