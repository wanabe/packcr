class Packcr
  class Node
    def seq(expr)
      SequenceNode.new(self, expr)
    end

    def alt(expr)
      AlternateNode.new(self, expr)
    end

    def setup_rule(rule)
      nodes.each do |node|
        node.setup_rule(rule)
      end
    end

    def nodes
      []
    end

    def reversible?(gen)
      false
    end
  end
end

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
