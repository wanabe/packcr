class Packcr
  class Node
    class RuleNode
      def get_code(gen, onfail, indent, bare, oncut)
        case gen.lang
        when :c
          erbout = +""
          erbout << "static pcc_thunk_chunk_t *pcc_evaluate_rule_#{name}(pcc_context_t *ctx) {\n    pcc_thunk_chunk_t *const chunk = pcc_thunk_chunk__create(ctx);\n    chunk->pos = ctx->position_offset;\n".freeze

          if gen.location
            erbout << "    chunk->pos_loc = ctx->position_offset_loc;\n".freeze
          end
          erbout << "    PCC_DEBUG(ctx->auxil, PCC_DBG_EVALUATE, \"#{name}\", ctx->level, chunk->pos, (ctx->buffer.buf + chunk->pos), (ctx->buffer.len - chunk->pos));\n    ctx->level++;\n    pcc_value_table__resize(ctx->auxil, &chunk->values, #{vars.length});\n    pcc_capture_table__resize(ctx->auxil, &chunk->capts, #{capts.length});\n".freeze

          if !vars.empty?
            erbout << "    pcc_value_table__clear(ctx->auxil, &chunk->values);\n".freeze
          end
          r = expr.reachability

          erbout << "#{gen.generate_code(expr, 0, 4, false)}    ctx->level--;\n    PCC_DEBUG(ctx->auxil, PCC_DBG_MATCH, \"#{name}\", ctx->level, chunk->pos, (ctx->buffer.buf + chunk->pos), (ctx->position_offset - chunk->pos));\n    return chunk;\n".freeze

          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "L0000:;\n    ctx->level--;\n    PCC_DEBUG(ctx->auxil, PCC_DBG_NOMATCH, \"#{name}\", ctx->level, chunk->pos, (ctx->buffer.buf + chunk->pos), (ctx->position_offset - chunk->pos));\n    pcc_thunk_chunk__destroy(ctx, chunk);\n    return NULL;\n".freeze
          end
          erbout << "}\n".freeze

          erbout
        when :rb
          erbout = +""
          erbout << "def evaluate_rule_#{name}(offset".freeze
          if gen.location
            erbout << ", offset_loc".freeze
          end
          erbout << ", limits: nil)\n  answer = ThunkChunk.new\n  answer.pos = @position_offset\n".freeze

          if gen.location
            erbout << "  answer.pos_loc = @position_offset_loc\n".freeze
          end
          erbout << "  debug { warn \"\#{ \"  \" * @level}EVAL    #{name} \#{answer.pos} \#{@buffer[answer.pos..-1].inspect}\" }\n  @level += 1\n  answer.resize_captures(#{capts.length})\n".freeze

          if !vars.empty?
            erbout << "  answer.values = {}\n".freeze
          end
          r = expr.reachability
          if r == Packcr::CODE_REACH__ALWAYS_SUCCEED

            erbout << "#{gen.generate_code(expr, 0, 2, false)}  @level -= 1\n  debug { warn \"\#{ \"  \" * @level}MATCH   #{name} \#{answer.pos} \#{@buffer[answer.pos...@position_offset].inspect}\" }\n  return answer\n".freeze

          else
            erbout << "  catch(0) do\n#{gen.generate_code(expr, 0, 4, false)}    @level -= 1\n    debug { warn \"\#{ \"  \" * @level}MATCH   #{name} \#{answer.pos} \#{@buffer[answer.pos...@position_offset].inspect}\" }\n    return answer\n  end\n  @level -= 1\n  debug { warn \"\#{ \"  \" * @level}NOMATCH #{name} \#{answer.pos} \#{@buffer[answer.pos...@position_offset].inspect}\" }\n  return nil\n".freeze
          end
          erbout << "end\n".freeze

          erbout
        end
      end
    end
  end
end
