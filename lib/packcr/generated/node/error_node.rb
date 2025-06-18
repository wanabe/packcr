class Packcr
  class Node
    class ErrorNode
      def get_code(gen, onfail, indent, unwrap, oncut)
        case gen.lang
        when :c
          erbout = +""
          erbout << "{\n".freeze

          l = gen.next_label
          m = gen.next_label

          erbout << "#{gen.generate_code(expr, l, 4, true)}    goto L#{format("%04d", m)};\nL#{format("%04d", l)}:;\n    {\n        packcr_value_t null;\n        packcr_thunk_t *const thunk = packcr_thunk__create_leaf(ctx->auxil, packcr_action_#{gen.rule.name}_#{index}, #{gen.rule.vars.length}, #{gen.rule.capts.length});\n".freeze

          vars.each do |var|
            erbout << "        thunk->data.leaf.values.buf[#{var.index}] = &(chunk->values.buf[#{var.index}]);\n".freeze
          end
          capts.each do |capt|
            erbout << "        thunk->data.leaf.capts.buf[#{capt.index}] = &(chunk->capts.buf[#{capt.index}]);\n".freeze
          end
          erbout << "        thunk->data.leaf.capt0.range.start = chunk->pos;\n        thunk->data.leaf.capt0.range.end = ctx->position_offset;\n".freeze

          if gen.location
            erbout << "        thunk->data.leaf.capt0.range.start_loc = chunk->pos_loc;\n        thunk->data.leaf.capt0.range.end_loc = ctx->position_offset_loc;\n".freeze
          end
          erbout << "        memset(&null, 0, sizeof(packcr_value_t)); /* in case */\n        thunk->data.leaf.action(ctx, thunk, &null);\n        packcr_thunk__destroy(ctx->auxil, thunk);\n    }\n    goto L#{format("%04d", onfail)};\nL#{format("%04d", m)}:;\n}\n".freeze

          erbout
        when :rb
          erbout = +""
          l = gen.next_label
          m = gen.next_label
          erbout << "catch(#{m}) do\n  catch(#{l}) do\n#{gen.generate_code(expr, l, 4, false)}    throw(#{m})\n  end\n\n  action_#{gen.rule.name}_#{index}(\n    ThunkLeaf.new(\n      :action_#{gen.rule.name}_#{index},\n      Capture.new(\n        answer.pos, @position_offset,\n".freeze

          if gen.location
            erbout << "        answer.pos_loc, @position_offset_loc,\n".freeze
          end
          erbout << "      ),\n".freeze

          if vars.empty?
            erbout << "      {},\n".freeze

          else
            erbout << "      answer.values.slice(".freeze
            vars.each_with_index do |var, i|
              erbout << "#{", " if i > 0}#{var.index}".freeze
            end
            erbout << "),\n".freeze
          end
          if capts.empty?
            erbout << "      {},\n".freeze

          else
            erbout << "      answer.capts.slice(".freeze
            capts.each_with_index do |capt, i|
              erbout << "#{", " if i > 0}#{capt.index}".freeze
            end
            erbout << "),\n".freeze
          end
          erbout << "    ),\n    nil,\n    0,\n  )\n\n  throw(#{onfail})\nend\n".freeze

          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end
    end
  end
end
