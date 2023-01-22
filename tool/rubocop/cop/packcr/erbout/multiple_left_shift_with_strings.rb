module RuboCop
  module Cop
    module Packcr
      module Erbout
        class MultipleLeftShiftWithStrings < RuboCop::Cop::Base
          extend RuboCop::Cop::AutoCorrector
          MSG = "Multiple `erbout << 'str'`".freeze

          def on_begin(node)
            range = nil
            targets = []
            (node.children + [nil]).each do |child|
              if child
                if !range
                  if check_node_is_erbout_shift(child)
                    range = child.source_range
                    targets = [child.arguments[0]]
                  end
                  next
                end
                if check_node_is_erbout_shift(child)
                  range = range.join(child.source_range)
                  targets << child.arguments[0]
                  next
                end
              end

              if targets[1]
                add_offense(range) do |rewriter|
                  rewriter.replace(range, "erbout << \"#{targets.map { |arg| str_scr(arg) }.join}\".freeze")
                end
              end
              range = nil
              targets = []
            end
          end

          def check_node_is_erbout_shift(node)
            return if !node&.send_type?
            return if node.method_name != :<<
            return if node.arguments.size != 1
            return if !node.receiver.lvar_type?
            return if node.receiver.source != "erbout"

            check_node_arg(node.arguments[0])
          end

          def check_node_arg(arg)
            case arg.type
            when :str, :dstr
              return true
            when :send
              return if arg.method_name != :freeze
              return if !arg.arguments.empty?

              return check_node_arg(arg.receiver)
            end

            false
          end

          def str_scr(arg)
            if arg.send_type?
              arg = arg.receiver
            end
            arg.source[1..-2]
          end
        end
      end
    end
  end
end
