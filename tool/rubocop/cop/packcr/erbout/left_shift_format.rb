module RuboCop
  module Cop
    module Packcr
      module Erbout
        class LeftShiftFormat < RuboCop::Cop::Base
          extend RuboCop::Cop::AutoCorrector
          MSG = "Invalid `erbout << obj` format".freeze
          RESTRICT_ON_SEND = %i[<<].freeze

          def on_send(node)
            return unless check_node_is_invalid_erbout_shift(node)

            add_offense(node) do |rewriter|
              src = "erbout << #{scr(node.arguments[0])}"
              rewriter.replace(node, src)
            end
          end

          def check_node_is_invalid_erbout_shift(node)
            return unless node&.send_type?
            return if node.method_name != :<<
            return if node.arguments.size != 1
            return if !node.receiver.lvar_type?
            return if node.receiver.source != "erbout"
            return if node.source =~ /\Aerbout << / && node.source !~ /to_s\)?\z/

            true
          end

          def scr(node)
            if node.send_type? && node.arguments.empty? && node.method_name == :to_s
              return "\"\#{#{node.receiver.source}}\".freeze"
            end
            if node.str_type? || node.dstr_type?
              return "#{node.source}.freeze"
            end

            node.source
          end
        end
      end
    end
  end
end
