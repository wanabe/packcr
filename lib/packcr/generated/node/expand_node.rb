class Packcr
  class Node
    class ExpandNode
      def get_code(gen, onfail, indent, bare, oncut)
        case gen.lang
        when :c
          erbout = +""
          erbout << "{\n    const size_t n = chunk->capts.buf[#{index}].range.end - chunk->capts.buf[#{index}].range.start;\n    if (pcc_refill_buffer(ctx, n) < n) goto L#{format("%04d", onfail)};\n    if (n > 0) {\n        const char *const p = ctx->buffer.buf + ctx->cur;\n        const char *const q = ctx->buffer.buf + chunk->capts.buf[#{index}].range.start;\n        size_t i;\n        for (i = 0; i < n; i++) {\n            if (p[i] != q[i]) goto L#{format("%04d", onfail)};\n        }\n".freeze

          if gen.location
            erbout << "        pcc_location_forward(&ctx->cur_loc, ctx->buffer.buf + ctx->cur, n);\n".freeze
          end
          erbout << "        ctx->cur += n;\n    }\n}\n".freeze

          erbout
        when :rb
          erbout = +""
          erbout << "capt#{gen.level} = answer.capts[#{index}]\nn#{gen.level} = capt#{gen.level}.range_end - capt#{gen.level}.range_start\nif refill_buffer(n#{gen.level}) < n#{gen.level}\n  throw(#{onfail})\nend\nif n#{gen.level} > 0\n  ptr#{gen.level} = @buffer[@position_offset, n#{gen.level}]\n  q#{gen.level} = @buffer[capt#{gen.level}.range_start, n#{gen.level}]\n  if ptr#{gen.level} != q#{gen.level}\n    throw(#{onfail})\n  end\n".freeze

          if gen.location
            erbout << "  @position_offset_loc = @position_offset_loc.forward(@buffer, @position_offset, n#{gen.level})\n".freeze
          end
          erbout << "  @position_offset += n#{gen.level}\nend\n".freeze

          erbout
        end
      end
    end
  end
end
