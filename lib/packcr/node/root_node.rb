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
      end

      def setup(ctx)
        make_rulehash(ctx)
        @rules.first&.top = true
        @rules.each do |rule|
          rule.setup(ctx)
        end
        @rules.each do |rule|
          rule.verify(ctx)
        end
      end

      def rule(name)
        rule = @rulehash[name]
        return rule if rule

        case name
        when "EOF"
          expr = Packcr::Node::EofNode.new
        else
          return nil
        end
        rule = Packcr::Node::RuleNode.new(expr, name)
        @rules << rule
        @rulehash[name] = rule
      end

      def to_h
        {
          type: :root,
          rules: rules.map(&:to_h),
        }
      end
    end
  end
end
