class Packcr
  class Node
    class RootNode < Packcr::Node
      attr_accessor :rules
      attr_reader :rulehash

      def initialize
        @rules = []
        @rulehash = {}
        @implicit_rules = []
      end

      def debug_dump
        @rules.each(&:debug_dump)
      end

      def make_rulehash(ctx)
        @rules.each do |rule|
          if @rulehash[rule.name]
            ctx.error rule.line + 1, rule.col + 1, "Multiple definition of rule '#{rule.name}'"
          else
            @rulehash[rule.name] = rule
          end
        end
        @implicit_rules.each do |rule|
          next if @rulehash[rule.name]
          @rules << rule
          @rulehash[rule.name] = rule
        end
      end

      def setup(ctx)
        make_rulehash(ctx)
        @rules.first&.top = true
        @rules.each do |rule|
          rule.setup
          rule.expr.link_references(ctx)
        end
        @rules.each do |rule|
          rule.verify(ctx)
        end
      end

      def implicit_rule(name)
        case name
        when "EOF"
          expr = Packcr::Node::EofNode.new
        else
          raise "Unexpected implicit rule: #{name.inspect}"
        end
        rule = Packcr::Node::RuleNode.new(expr, name)
        @implicit_rules << rule
      end
    end
  end
end
