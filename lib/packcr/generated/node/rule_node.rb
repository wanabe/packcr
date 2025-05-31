class Packcr
  class Node
    class RuleNode
      def get_code(gen, onfail, indent, unwrap, oncut)
        case gen.lang
        when :c
          erbout = +""
          erbout << "static packcr_thunk_chunk_t *packcr_evaluate_rule_#{name}(packcr_context_t *ctx, size_t offset".freeze
          if gen.location
            erbout << ", packcr_location_t offset_loc".freeze
          end
          erbout << ", packcr_rule_set_t *limits) {\n    packcr_thunk_chunk_t *const chunk = packcr_thunk_chunk__create(ctx);\n    chunk->pos = ctx->position_offset;\n".freeze

          if gen.location
            erbout << "    chunk->pos_loc = ctx->position_offset_loc;\n".freeze
          end
          erbout << "    PACKCR_DEBUG(ctx->auxil, PACKCR_DBG_EVALUATE, \"#{name}\", ctx->level, chunk->pos, (ctx->buffer.buf + chunk->pos), (ctx->buffer.len - chunk->pos));\n    ctx->level++;\n    packcr_value_table__resize(ctx->auxil, &chunk->values, #{vars.length});\n    packcr_capture_table__resize(ctx->auxil, &chunk->capts, #{capts.length});\n".freeze

          if !vars.empty?
            erbout << "    packcr_value_table__clear(ctx->auxil, &chunk->values);\n".freeze
          end
          r = expr.reachability

          erbout << "#{gen.generate_code(expr, 0, 4, false)}    ctx->level--;\n    PACKCR_DEBUG(ctx->auxil, PACKCR_DBG_MATCH, \"#{name}\", ctx->level, chunk->pos, (ctx->buffer.buf + chunk->pos), (ctx->position_offset - chunk->pos));\n    return chunk;\n".freeze

          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "L0000:;\n    ctx->level--;\n    PACKCR_DEBUG(ctx->auxil, PACKCR_DBG_NOMATCH, \"#{name}\", ctx->level, chunk->pos, (ctx->buffer.buf + chunk->pos), (ctx->position_offset - chunk->pos));\n    packcr_thunk_chunk__destroy(ctx, chunk);\n    return NULL;\n".freeze
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
        when :rs
          erbout = +""
          for_ref = has_ref ? "" : "_"
          erbout << "#[allow(non_snake_case)]\nfn evaluate_rule_#{name}(&mut self, #{for_ref}offset: usize, ".freeze

          if gen.location
            erbout << "    TODO\n".freeze
          end

          erbout << "#{for_ref}limits: RuleLimit) -> Option<ThunkChunk> {\n    let mut answer = ThunkChunk::new(self.input.position_offset);\n".freeze

          if gen.location
            erbout << "    TODO\n".freeze
          end
          erbout << "    self.level += 1;\n    answer.capts.resize(#{capts.length});\n".freeze

          if !vars.empty?
            erbout << "    answer.values.clear();\n".freeze
          end
          r = expr.reachability
          if r == Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "    let _ = (|| {\n#{gen.generate_code(expr, 0, 8, false)}        NOP\n    })();\n    self.level -= 1;\n    Some(answer)\n".freeze

          else
            erbout << "    match (|| {\n#{gen.generate_code(expr, 0, 8, false)}        NOP\n    })() {\n        NOP => {\n            self.level -= 1;\n            Some(answer)\n        }\n        _ => {\n            self.level -= 1;\n            None\n        }\n    }\n".freeze
          end
          erbout << "}\n".freeze

          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end
    end
  end
end
