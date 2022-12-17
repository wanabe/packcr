class Packcr
  class Node
    attr_reader :codes

    attr_accessor :name, :expr, :index, :index, :vars, :capts, :nodes, :code, :neg, :ref, :var, :rule
    attr_accessor :value, :min, :max, :line, :col

    def initialize
      super
      @codes = []
    end

    def debug_dump(indent = 0)
      # raise "Internal error"
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
