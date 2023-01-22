class Packcr
  class Node
    class ActionNode
      def get_code(gen, onfail, indent, bare, oncut)
        case gen.lang
        when :c
          erbout = +""
          erbout << "{\n    pcc_thunk_t *const thunk = pcc_thunk__create_leaf(ctx->auxil, pcc_action_#{gen.rule.name}_#{index}, #{gen.rule.vars.length}, #{gen.rule.capts.length});\n".freeze

          vars.each do |var|
            erbout << "    thunk->data.leaf.values.buf[#{var.index}] = &(chunk->values.buf[#{var.index}]);\n".freeze
          end
          capts.each do |capt|
            erbout << "    thunk->data.leaf.capts.buf[#{capt.index}] = &(chunk->capts.buf[#{capt.index}]);\n".freeze
          end
          erbout << "    thunk->data.leaf.capt0.range.start = chunk->pos;\n    thunk->data.leaf.capt0.range.end = ctx->cur;\n".freeze

          if gen.location
            erbout << "    thunk->data.leaf.capt0.range.start_loc_ptr = &chunk->pos_loc;\n    thunk->data.leaf.capt0.range.end_loc_ptr = &ctx->cur_loc;\n".freeze
          end
          erbout << "    pcc_thunk_array__add(ctx->auxil, &chunk->thunks, thunk);\n}\n".freeze

          erbout
        when :rb
          erbout = +""
          erbout << "answer.thunks.push(\n  ThunkLeaf.new(\n    :action_#{gen.rule.name}_#{index},\n    Capture.new(\n      answer.pos, @position_offset,\n".freeze

          if gen.location
            erbout << "      answer.pos_loc, @position_offset_loc,\n".freeze
          end
          erbout << "    ),\n".freeze

          if vars.empty?
            erbout << "    {},\n".freeze

          else
            erbout << "    answer.values.slice(".freeze
            vars.each_with_index do |var, i|
              erbout << "#{", " if i > 0}#{var.index}".freeze
            end
            erbout << "),\n".freeze
          end
          if capts.empty?
            erbout << "    {},\n".freeze

          else
            erbout << "    answer.capts.slice(".freeze
            capts.each_with_index do |capt, i|
              erbout << "#{", " if i > 0}#{capt.index}".freeze
            end
            erbout << "),\n".freeze
          end
          erbout << "  )\n)\n".freeze

          erbout
        end
      end
    end
  end
end
