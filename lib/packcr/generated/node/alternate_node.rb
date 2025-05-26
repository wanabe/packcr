class Packcr
  class Node
    class AlternateNode
      def get_code(gen, onfail, indent, bare, oncut)
        case gen.lang
        when :c
          erbout = +""
          m = gen.next_label
          erbout << "{\n    const size_t p = ctx->position_offset;\n".freeze

          if gen.location
            erbout << "    const packcr_location_t p_loc = ctx->position_offset_loc;\n".freeze
          end
          erbout << "    const size_t n = chunk->thunks.len;\n".freeze

          nodes.each_with_index do |expr, i|
            c = i + 1 < nodes.length
            l = gen.next_label
            r = expr.reachability

            erbout << "#{gen.generate_code(expr, l, 4, false)}".freeze
            if r == Packcr::CODE_REACH__ALWAYS_SUCCEED
              if c
                erbout << "    /* unreachable codes omitted */\n".freeze
              end
              break
            elsif r == Packcr::CODE_REACH__BOTH
              erbout << "    goto L#{format("%04d", m)};\n".freeze
            end
            erbout << "L#{format("%04d", l)}:;\n    ctx->position_offset = p;\n".freeze

            if gen.location
              erbout << "    ctx->position_offset_loc = p_loc;\n".freeze
            end
            erbout << "    packcr_thunk_array__revert(ctx->auxil, &chunk->thunks, n);\n".freeze

            next if c

            erbout << "    goto L#{format("%04d", onfail)};\n".freeze
          end
          erbout << "L#{format("%04d", m)}:;\n}\n".freeze

          erbout
        when :rb
          erbout = +""
          m = gen.next_label
          erbout << "catch(#{m}) do\n  pos#{gen.level} = @position_offset\n".freeze

          if gen.location
            erbout << "  p_loc#{gen.level} = @position_offset_loc\n".freeze
          end
          erbout << "  n#{gen.level} = answer.thunks.length\n".freeze

          nodes.each_with_index do |expr, i|
            c = i + 1 < nodes.length
            if expr.reversible?(gen)

              erbout << "#{gen.generate_code(expr, m, 2, false, reverse: true, oncut: onfail)}".freeze
            else
              l = gen.next_label
              erbout << "  catch(#{l}) do\n".freeze

              r = expr.reachability

              erbout << "#{gen.generate_code(expr, l, 4, false, oncut: onfail)}".freeze
              if r == Packcr::CODE_REACH__ALWAYS_SUCCEED
                if c
                  erbout << "    # unreachable codes omitted\n".freeze
                end
                erbout << "  end\n".freeze

                break
              elsif r == Packcr::CODE_REACH__BOTH
                erbout << "    throw(#{m})\n".freeze
              end
              erbout << "  end\n".freeze
            end
            erbout << "  @position_offset = pos#{gen.level}\n".freeze

            if gen.location
              erbout << "  @position_offset_loc = p_loc#{gen.level}\n".freeze
            end
            erbout << "  answer.thunks[n#{gen.level}..-1] = []\n".freeze

            next if c

            erbout << "  throw(#{onfail})\n".freeze
          end
          erbout << "end\n".freeze

          erbout
        when :rs
          erbout = +""
          m = gen.next_label
          erbout << "'L#{format("%04d", m)}: {\n    let p = self.input.position_offset;\n".freeze

          if gen.location
            erbout << "    TODO\n".freeze
          end
          nodes.each_with_index do |expr, i|
            erbout << "    {\n".freeze

            c = i + 1 < nodes.length
            if expr.reversible?(gen)

              erbout << "#{gen.generate_code(expr, m, 8, false, reverse: true, oncut: onfail)}".freeze
            else
              l = gen.next_label
              erbout << "        'L#{format("%04d", l)}: {\n".freeze

              r = expr.reachability

              erbout << "#{gen.generate_code(expr, l, 12, false, oncut: onfail)}".freeze
              if r == Packcr::CODE_REACH__ALWAYS_SUCCEED
                if c
                  erbout << "            // unreachable codes omitted\n".freeze
                end
                erbout << "        }\n".freeze

                break
              elsif r == Packcr::CODE_REACH__BOTH
                erbout << "            break 'L#{format("%04d", m)};\n".freeze
              end
              erbout << "        }\n".freeze
            end
            erbout << "    }\n    self.input.position_offset = p;\n".freeze

            if gen.location
              erbout << "    TODO\n".freeze
            end
            next if c

            erbout << "    break 'L#{format("%04d", onfail)};\n".freeze
          end
          erbout << "} // 'L#{format("%04d", m)}\n".freeze

          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end
    end
  end
end
