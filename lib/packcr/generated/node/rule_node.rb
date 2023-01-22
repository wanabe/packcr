class Packcr
  class Node
    class RuleNode
      def get_code(gen, onfail, indent, bare, oncut)
        case gen.lang
        when :c
          erbout = +""
          erbout << "    PCC_DEBUG(ctx->auxil, PCC_DBG_EVALUATE, \"#{name}\", ctx->level, chunk->pos, (ctx->buffer.buf + chunk->pos), (ctx->buffer.len - chunk->pos));\n    ctx->level++;\n    pcc_value_table__resize(ctx->auxil, &chunk->values, #{vars.length});\n    pcc_capture_table__resize(ctx->auxil, &chunk->capts, #{capts.length});\n".freeze

          if !vars.empty?
            erbout << "    pcc_value_table__clear(ctx->auxil, &chunk->values);\n".freeze
          end
          r = expr.reachability

          erbout << "#{gen.generate_code(expr, 0, 4, false)}    ctx->level--;\n    PCC_DEBUG(ctx->auxil, PCC_DBG_MATCH, \"#{name}\", ctx->level, chunk->pos, (ctx->buffer.buf + chunk->pos), (ctx->cur - chunk->pos));\n    return chunk;\n".freeze

          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "L0000:;\n    ctx->level--;\n    PCC_DEBUG(ctx->auxil, PCC_DBG_NOMATCH, \"#{name}\", ctx->level, chunk->pos, (ctx->buffer.buf + chunk->pos), (ctx->cur - chunk->pos));\n    pcc_thunk_chunk__destroy(ctx, chunk);\n    return NULL;\n".freeze
          end
          erbout
        when :rb
          erbout = +""
          erbout << "debug { warn \"\#{ \"  \" * @level}EVAL    #{name} \#{answer.pos} \#{@buffer[answer.pos..-1].inspect}\" }\n@level += 1\nanswer.resize_captures(#{capts.length})\n".freeze

          if !vars.empty?
            erbout << "answer.values = {}\n".freeze
          end
          r = expr.reachability
          if r == Packcr::CODE_REACH__ALWAYS_SUCCEED

            erbout << "#{gen.generate_code(expr, 0, 0, false)}@level -= 1\ndebug { warn \"\#{ \"  \" * @level}MATCH   #{name} \#{answer.pos} \#{@buffer[answer.pos...@position_offset].inspect}\" }\nreturn answer\n".freeze

          else
            erbout << "catch(0) do\n#{gen.generate_code(expr, 0, 2, false)}  @level -= 1\n  debug { warn \"\#{ \"  \" * @level}MATCH   #{name} \#{answer.pos} \#{@buffer[answer.pos...@position_offset].inspect}\" }\n  return answer\nend\n@level -= 1\ndebug { warn \"\#{ \"  \" * @level}NOMATCH #{name} \#{answer.pos} \#{@buffer[answer.pos...@position_offset].inspect}\" }\nreturn nil\n".freeze
          end
          erbout
        end
      end
    end
  end
end
