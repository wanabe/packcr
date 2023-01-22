class Packcr
  class Node
    class QuantityNode
      def get_many_code(gen, onfail, indent, bare, oncut)
        case gen.lang
        when :c
          erbout = +""
          erbout << "{\n".freeze

          if min > 0
            erbout << "    const size_t p0 = ctx->cur;\n".freeze

            if gen.location
              erbout << "    const pcc_location_t p0_loc = ctx->cur_loc;\n".freeze
            end
            erbout << "    const size_t n0 = chunk->thunks.len;\n".freeze
          end
          erbout << "    int i;\n".freeze

          if max < 0
            erbout << "    for (i = 0;; i++) {\n".freeze

          else
            erbout << "    for (i = 0; i < #{max}; i++) {\n".freeze
          end
          erbout << "        const size_t p = ctx->cur;\n".freeze

          if gen.location
            erbout << "        const pcc_location_t p_loc = ctx->cur_loc;\n".freeze
          end
          erbout << "        const size_t n = chunk->thunks.len;\n".freeze

          l = gen.next_label
          r = expr.reachability
          erbout << "#{gen.generate_code(expr, l, 8, false)}        if (ctx->cur == p) break;\n".freeze

          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "        continue;\n    L#{format("%04d", l)}:;\n        ctx->cur = p;\n".freeze

            if gen.location
              erbout << "        ctx->cur_loc = p_loc;\n".freeze
            end
            erbout << "        pcc_thunk_array__revert(ctx->auxil, &chunk->thunks, n);\n        break;\n".freeze
          end
          erbout << "    }\n".freeze

          if min > 0
            erbout << "    if (i < #{min}) {\n        ctx->cur = p0;\n".freeze

            if gen.location
              erbout << "        ctx->cur_loc = p0_loc;\n".freeze
            end
            erbout << "        pcc_thunk_array__revert(ctx->auxil, &chunk->thunks, n0);\n        goto L#{format("%04d", onfail)};\n    }\n".freeze
          end
          erbout << "}\n".freeze

          erbout
        when :rb
          erbout = +""
          if min > 0
            erbout << "q#{gen.level} = @position_offset\n".freeze

            if gen.location
              erbout << "q_loc#{gen.level} = @position_offset_loc\n".freeze
            end
            erbout << "m#{gen.level} = answer.thunks.length\n".freeze
          end
          erbout << "i#{gen.level} = 0\npos#{gen.level} = nil\n".freeze

          if gen.location
            erbout << "p_loc#{gen.level} = nil\n".freeze
          end
          erbout << "n#{gen.level} = nil\n".freeze

          l = gen.next_label
          erbout << "catch(#{l}) do\n  pos#{gen.level} = @position_offset\n".freeze

          if gen.location
            erbout << "  p_loc#{gen.level} = @position_offset_loc\n".freeze
          end
          erbout << "  n#{gen.level} = answer.thunks.length\n".freeze

          r = expr.reachability

          erbout << "#{gen.generate_code(expr, l, 2, false)}  i#{gen.level} += 1\n  if @position_offset != pos#{gen.level}".freeze
          if max >= 0
            erbout << " || i#{gen.level} < #{max}".freeze
          end
          erbout << "\n    redo\n  end\n  pos#{gen.level} = nil\nend\n".freeze

          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "if pos#{gen.level}\n  @position_offset = pos#{gen.level}\n".freeze

            if gen.location
              erbout << "  @position_offset_loc = p_loc#{gen.level}\n".freeze
            end
            erbout << "  answer.thunks[n#{gen.level}..-1] = []\nend\n".freeze
          end
          if min > 0
            erbout << "if i#{gen.level} < #{min}\n  @position_offset = q#{gen.level}\n".freeze

            if gen.location
              erbout << "  @position_offset_loc = q_loc#{gen.level}\n".freeze
            end
            erbout << "  answer.thunks[m#{gen.level}..-1] = []\n  throw(#{onfail})\nend\n".freeze
          end
          erbout
        end
      end

      def get_one_code(gen, onfail, indent, bare, oncut)
        case gen.lang
        when :c
          erbout = +""
          erbout << "{\n".freeze

          l = gen.next_label
          erbout << "    const size_t p = ctx->cur;\n".freeze

          if gen.location
            erbout << "    const pcc_location_t p_loc = ctx->cur_loc;\n".freeze
          end
          erbout << "    const size_t n = chunk->thunks.len;\n".freeze

          r = expr.reachability
          erbout << "#{gen.generate_code(expr, l, 4, false)}".freeze
          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            m = gen.next_label
            erbout << "    goto L#{format("%04d", m)};\nL#{format("%04d", l)}:;\n".freeze

            if gen.location
              erbout << "    ctx->cur_loc = p_loc;\n".freeze
            end
            erbout << "    ctx->cur = p;\n    pcc_thunk_array__revert(ctx->auxil, &chunk->thunks, n);\nL#{format("%04d", m)}:;\n".freeze
          end
          erbout << "}\n".freeze

          erbout
        when :rb
          erbout = +""
          l = gen.next_label
          erbout << "pos#{gen.level} = @position_offset\n".freeze

          if gen.location
            erbout << "p_loc#{gen.level} = @position_offset_loc\n".freeze
          end
          erbout << "n#{gen.level} = answer.thunks.length\n".freeze

          r = expr.reachability
          if r == Packcr::CODE_REACH__ALWAYS_SUCCEED

            erbout << "#{gen.generate_code(expr, l, 0, false)}".freeze
          else
            m = gen.next_label
            erbout << "catch(#{m}) do\n  catch(#{l}) do\n#{gen.generate_code(expr, l, 4, false)}    throw(#{m})\n  end\n".freeze

            if gen.location
              erbout << "  @position_offset_loc = p_loc#{gen.level}\n".freeze
            end
            erbout << "  @position_offset = pos#{gen.level}\n  answer.thunks[n#{gen.level}..-1] = []\nend\n".freeze
          end
          erbout
        end
      end
    end
  end
end
