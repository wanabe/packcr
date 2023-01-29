class Packcr
  class Node
    class ReferenceNode
      def get_code(gen, onfail, indent, bare, oncut)
        case gen.lang
        when :c
          erbout = +""
          if index.nil?
            erbout << "{\n    packcr_rule_set_t *l = NULL;\n    if (limits && ctx->position_offset == offset && packcr_rule_set__index(ctx->auxil, limits, packcr_evaluate_rule_#{name}) == PACKCR_VOID_VALUE) {\n        l = limits;\n    }\n    if (!packcr_apply_rule(ctx, packcr_evaluate_rule_#{name}, &chunk->thunks, NULL, offset".freeze
          else
            erbout << "{\n    packcr_rule_set_t *l = NULL;\n    if (limits && ctx->position_offset == offset && packcr_rule_set__index(ctx->auxil, limits, packcr_evaluate_rule_#{name}) == PACKCR_VOID_VALUE) {\n        l = limits;\n    }\n    if (!packcr_apply_rule(ctx, packcr_evaluate_rule_#{name}, &chunk->thunks, &(chunk->values.buf[#{index}]), offset".freeze

          end
          if gen.location
            erbout << ", offset_loc".freeze
          end
          erbout << ", l)) goto L#{format("%04d", onfail)};\n}\n".freeze
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
