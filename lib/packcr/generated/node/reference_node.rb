class Packcr
  class Node
    class ReferenceNode
      def get_code(gen, onfail, indent, bare, oncut)
        case gen.lang
        when :c
          erbout = +""
          if index.nil?
            erbout << "if (!pcc_apply_rule(ctx, pcc_evaluate_rule_#{name}, &chunk->thunks, NULL)) goto L#{format("%04d", onfail)};\n".freeze
          else
            erbout << "if (!pcc_apply_rule(ctx, pcc_evaluate_rule_#{name}, &chunk->thunks, &(chunk->values.buf[#{index}]))) goto L#{format("%04d", onfail)};\n".freeze

          end
          erbout
        when :rb
          erbout = +""
          if index.nil?
            erbout << "if limits && @position_offset == offset && !limits[:evaluate_rule_#{name}]\n  if !apply_rule(:evaluate_rule_#{name}, answer.thunks, nil, 0, offset".freeze
            if gen.location
              erbout << ", offset_loc".freeze
            end
            erbout << ", limits: limits)\n    throw(#{onfail})\n  end\nelse\n  if !apply_rule(:evaluate_rule_#{name}, answer.thunks, nil, 0, offset".freeze
          else
            erbout << "if limits && @position_offset == offset && !limits[:evaluate_rule_#{name}]\n  if !apply_rule(:evaluate_rule_#{name}, answer.thunks, answer.values, #{index}, offset".freeze
            if gen.location
              erbout << ", offset_loc".freeze
            end
            erbout << ", limits: limits)\n    throw(#{onfail})\n  end\nelse\n  if !apply_rule(:evaluate_rule_#{name}, answer.thunks, answer.values, #{index}, offset".freeze

          end
          if gen.location
            erbout << ", offset_loc".freeze
          end
          erbout << ")\n    throw(#{onfail})\n  end\nend\n".freeze
          erbout
        end
      end

      def get_reverse_code(gen, onsuccess, indent, bare, oncut)
        case gen.lang
        when :rb
          erbout = +""
          if index.nil?
            erbout << "if limits && @position_offset == offset && !limits[:evaluate_rule_#{name}]\n  if apply_rule(:evaluate_rule_#{name}, answer.thunks, nil, 0, offset".freeze
            if gen.location
              erbout << ", offset_loc".freeze
            end
            erbout << ", limits: limits)\n    throw(#{onsuccess})\n  end\nelse\n  if apply_rule(:evaluate_rule_#{name}, answer.thunks, nil, 0, offset".freeze
          else
            erbout << "if limits && @position_offset == offset && !limits[:evaluate_rule_#{name}]\n  if apply_rule(:evaluate_rule_#{name}, answer.thunks, answer.values, #{index}, offset".freeze
            if gen.location
              erbout << ", offset_loc".freeze
            end
            erbout << ", limits: limits)\n    throw(#{onsuccess})\n  end\nelse\n  if apply_rule(:evaluate_rule_#{name}, answer.thunks, answer.values, #{index}, offset".freeze

          end
          if gen.location
            erbout << ", offset_loc".freeze
          end
          erbout << ")\n    throw(#{onsuccess})\n  end\nend\n".freeze
          erbout
        end
      end
    end
  end
end
