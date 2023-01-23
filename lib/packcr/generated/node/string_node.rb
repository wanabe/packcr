class Packcr
  class Node
    class StringNode
      def get_many_code(gen, onfail, indent, bare, oncut, n)
        case gen.lang
        when :c
          erbout = +""
          erbout << "if (\n    pcc_refill_buffer(ctx, #{n}) < #{n} ||\n".freeze

          (n - 1).times do |i|
            erbout << "    (ctx->buffer.buf + ctx->position_offset)[#{i}] != '#{Packcr.escape_character(value[i])}' ||\n".freeze
          end
          erbout << "    (ctx->buffer.buf + ctx->position_offset)[#{n - 1}] != '#{Packcr.escape_character(value[n - 1])}'\n) goto L#{format("%04d", onfail)};\n".freeze

          if gen.location
            erbout << "pcc_location_forward(&ctx->position_offset_loc, ctx->buffer.buf + ctx->position_offset, n);\n".freeze
          end
          erbout << "ctx->position_offset += #{n};\n".freeze

          erbout
        when :rb
          erbout = +""
          erbout << "if (\n  refill_buffer(#{n}) < #{n} ||\n  @buffer[@position_offset, #{n}] != #{value[0, n].dump}\n)\n  throw(#{onfail})\nend\n".freeze

          if gen.location
            erbout << "@position_offset_loc = @position_offset_loc.forward(@buffer, @position_offset, #{n})\n".freeze
          end
          erbout << "@position_offset += #{n}\n".freeze

          erbout
        end
      end

      def get_one_code(gen, onfail, indent, bare, oncut, n)
        case gen.lang
        when :c
          erbout = +""
          erbout << "if (\n    pcc_refill_buffer(ctx, 1) < 1 ||\n    ctx->buffer.buf[ctx->position_offset] != '#{Packcr.escape_character(value[0])}'\n) goto L#{format("%04d", onfail)};\n".freeze

          if gen.location
            erbout << "    pcc_location_forward(&ctx->position_offset_loc, ctx->buffer.buf + ctx->position_offset, 1);\n".freeze
          end
          erbout << "ctx->position_offset++;\n".freeze

          erbout
        when :rb
          erbout = +""
          erbout << "if (\n  refill_buffer(1) < 1 ||\n  @buffer[@position_offset] != \"#{Packcr.escape_character(value[0])}\"\n)\n  throw(#{onfail})\nend\n".freeze

          if gen.location
            erbout << "@position_offset_loc = @position_offset_loc.forward(@buffer, @position_offset, 1)\n".freeze
          end
          erbout << "@position_offset += 1\n".freeze

          erbout
        end
      end
    end
  end
end
