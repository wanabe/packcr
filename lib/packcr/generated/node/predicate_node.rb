class Packcr
  class Node
    class PredicateNode
      def get_code(gen, onfail, indent, unwrap, oncut)
        case gen.lang
        when :c
          erbout = +""
          l = gen.next_label
          m = gen.next_label
          r = expr.reachability
          erbout << "{\n    const size_t p = ctx->position_offset;\n".freeze

          if gen.location
            erbout << "    const packcr_location_t p_loc = ctx->position_offset_loc;\n".freeze
          end
          erbout << "#{gen.generate_code(expr, l, 4, false)}".freeze
          if r != Packcr::CODE_REACH__ALWAYS_FAIL
            erbout << "    ctx->position_offset = p;\n".freeze

            if gen.location
              erbout << "    ctx->position_offset_loc = p_loc;\n".freeze
            end
          end
          if r == Packcr::CODE_REACH__BOTH
            erbout << "    goto L#{format("%04d", m)};\n".freeze
          end
          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "L#{format("%04d", l)}:;\n    ctx->position_offset = p;\n".freeze

            if gen.location
              erbout << "    ctx->position_offset_loc = p_loc;\n".freeze
            end
            erbout << "    goto L#{format("%04d", onfail)};\n".freeze
          end
          if r == Packcr::CODE_REACH__BOTH
            erbout << "L#{format("%04d", m)}:;\n".freeze
          end
          erbout << "}\n".freeze

          erbout
        when :rb
          erbout = +""
          l = gen.next_label
          m = gen.next_label
          r = expr.reachability
          erbout << "catch(#{m}) do\n  pos#{gen.level} = @position_offset\n".freeze

          if gen.location
            erbout << "  p_loc#{gen.level} = @position_offset_pos\n".freeze
          end
          erbout << "  catch(#{l}) do\n#{gen.generate_code(expr, l, 4, false)}".freeze
          if r != Packcr::CODE_REACH__ALWAYS_FAIL
            erbout << "    @position_offset = pos#{gen.level}\n".freeze

            if gen.location
              erbout << "    @position_offset_loc = p_loc#{gen.level}\n".freeze
            end
          end
          if r == Packcr::CODE_REACH__BOTH
            erbout << "    throw(#{m})\n".freeze
          end
          erbout << "  end\n".freeze

          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "  @position_offset = pos#{gen.level}\n".freeze

            if gen.location
              erbout << "  @position_offset_loc = p_loc#{gen.level}\n".freeze
            end
            erbout << "  throw(#{onfail})\n".freeze
          end
          erbout << "end\n".freeze

          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end

      def get_neg_code(gen, onfail, indent, unwrap, oncut)
        case gen.lang
        when :c
          erbout = +""
          l = gen.next_label
          r = expr.reachability
          erbout << "{\n    const size_t p = ctx->position_offset;\n".freeze

          if gen.location
            erbout << "    const packcr_location_t p_loc = ctx->position_offset_loc;\n".freeze
          end
          erbout << "#{gen.generate_code(expr, l, 4, false)}".freeze
          if r != Packcr::CODE_REACH__ALWAYS_FAIL
            erbout << "    ctx->position_offset = p;\n".freeze

            if gen.location
              erbout << "    ctx->position_offset_loc = p_loc;\n".freeze
            end
            erbout << "    goto L#{format("%04d", onfail)};\n".freeze
          end
          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "L#{format("%04d", l)}:;\n    ctx->position_offset = p;\n".freeze

            if gen.location
              erbout << "    ctx->position_offset_loc = p_loc;\n".freeze
            end
          end
          erbout << "}\n".freeze

          erbout
        when :rb
          erbout = +""
          l = gen.next_label
          r = expr.reachability
          erbout << "pos#{gen.level} = @position_offset\n".freeze

          if gen.location
            erbout << "p_loc#{gen.level} = @position_offset_loc\n".freeze
          end
          erbout << "catch(#{l}) do\n#{gen.generate_code(expr, l, 2, false)}".freeze
          if r != Packcr::CODE_REACH__ALWAYS_FAIL
            erbout << "  @position_offset = pos#{gen.level}\n".freeze

            if gen.location
              erbout << "  @position_offset_loc = p_loc#{gen.level}\n".freeze
            end
            erbout << "  throw(#{onfail})\n".freeze
          end
          erbout << "end\n".freeze

          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "@position_offset = pos#{gen.level}\n".freeze

            if gen.location
              erbout << "@position_offset_loc = p_loc#{gen.level}\n".freeze
            end
          end
          erbout
        when :rs
          erbout = +""
          l = gen.next_label
          r = expr.reachability
          erbout << "let p = self.input.position_offset;\ncatch(#{l}, || {\n#{gen.generate_code(expr, l, 4, false)}".freeze
          if r == Packcr::CODE_REACH__ALWAYS_FAIL
            erbout << "    NOP\n".freeze
          else
            erbout << "    self.input.position_offset = p;\n    throw(#{onfail})\n".freeze

          end
          erbout << "})?;\n".freeze

          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "self.input.position_offset = p;\n".freeze
          end
          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end
    end
  end
end
