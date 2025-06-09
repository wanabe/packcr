class Packcr
  class Node
    class QuantityNode
      def get_many_code(gen, onfail, indent, unwrap, oncut)
        case gen.lang
        when :c
          erbout = +""
          erbout << "{\n".freeze

          r = expr.reachability
          if min > 0
            erbout << "    const size_t p0 = ctx->position_offset;\n".freeze

            if gen.location
              erbout << "    const packcr_location_t p0_loc = ctx->position_offset_loc;\n".freeze
            end
            erbout << "    const size_t n0 = chunk->thunks.len;\n".freeze
          end
          erbout << "    int i;\n".freeze

          if max < 0
            erbout << "    for (i = 0;; i++) {\n".freeze

          else
            erbout << "    for (i = 0; i < #{max}; i++) {\n".freeze
          end
          erbout << "        const size_t p = ctx->position_offset;\n".freeze

          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            if gen.location
              erbout << "        const packcr_location_t p_loc = ctx->position_offset_loc;\n".freeze
            end
            erbout << "        const size_t n = chunk->thunks.len;\n".freeze
          end
          l = gen.next_label
          erbout << "#{gen.generate_code(expr, l, 8, false)}        if (ctx->position_offset == p) break;\n".freeze

          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "        continue;\n    L#{format("%04d", l)}:;\n        ctx->position_offset = p;\n".freeze

            if gen.location
              erbout << "        ctx->position_offset_loc = p_loc;\n".freeze
            end
            erbout << "        packcr_thunk_array__revert(ctx->auxil, &chunk->thunks, n);\n        break;\n".freeze
          end
          erbout << "    }\n".freeze

          if min > 0
            erbout << "    if (i < #{min}) {\n        ctx->position_offset = p0;\n".freeze

            if gen.location
              erbout << "        ctx->position_offset_loc = p0_loc;\n".freeze
            end
            erbout << "        packcr_thunk_array__revert(ctx->auxil, &chunk->thunks, n0);\n        goto L#{format("%04d", onfail)};\n    }\n".freeze
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
        when :rs
          erbout = +""
          if min > 0
            erbout << "let q = self.input.position_offset;\n".freeze
          end
          use_count = max >= 0 || min > 0
          if use_count
            erbout << "let mut i = -1;\n".freeze
          end
          m = gen.next_label
          erbout << "catch(#{m}, || {\n    loop {\n".freeze

          if use_count
            erbout << "        i += 1;\n".freeze
          end
          if max >= 0
            erbout << "        if i >= #{max} {\n            return NOP;\n        }\n".freeze
          end
          erbout << "        let p = self.input.position_offset;\n".freeze

          l = gen.next_label
          r = expr.reachability
          if r == Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "        TODO\n        match (|| {\n#{gen.generate_code(expr, l, 12, false)}            if self.input.position_offset".freeze
            if gen.location
              erbout << ".position".freeze
            end
            erbout << " == p".freeze
            if gen.location
              erbout << ".position".freeze
            end
            erbout << " {\n                return throw(#{m});\n            }\n        })() {\n            NOP => continue,\n            Err(label) if label != #{l} => return throw(label),\n            _ => {\n                self.input.position_offset = p;\n                return throw(#{m});\n            }\n        }\n".freeze

          elsif expr.reversible?(gen)
            erbout << "        catch(#{l}, || {\n#{gen.generate_code(expr, l, 12, false, reverse: true)}            self.input.position_offset = p;\n            throw(#{m})\n        })?;\n        if self.input.position_offset".freeze

            if gen.location
              erbout << ".position".freeze
            end
            erbout << " == p".freeze
            if gen.location
              erbout << ".position".freeze
            end
            erbout << " {\n            return throw(#{m});\n        };\n".freeze

          else
            erbout << "        let label = (|| {\n#{gen.generate_code(expr, l, 12, false)}            if self.input.position_offset".freeze
            if gen.location
              erbout << ".position".freeze
            end
            erbout << " == p".freeze
            if gen.location
              erbout << ".position".freeze
            end
            erbout << " {\n                return throw(#{m});\n            }\n            NOP\n        })();\n        if let Err(#{l}) = label {\n            self.input.position_offset = p;\n            return throw(#{m});\n        };\n        label?;\n".freeze
          end
          erbout << "    }\n})?;\n".freeze

          if min > 0
            erbout << "if i < #{min} {\n    self.input.position_offset = q;\n    return throw(#{onfail});\n}\n".freeze
          end
          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end

      def get_one_code(gen, onfail, indent, unwrap, oncut)
        case gen.lang
        when :c
          erbout = +""
          r = expr.reachability
          if r == Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "#{gen.generate_code(expr, nil, 0, true)}".freeze
          else
            erbout << "{\n".freeze

            l = gen.next_label
            erbout << "    const size_t p = ctx->position_offset;\n".freeze

            if gen.location
              erbout << "    const packcr_location_t p_loc = ctx->position_offset_loc;\n".freeze
            end
            erbout << "    const size_t n = chunk->thunks.len;\n#{gen.generate_code(expr, l, 4, false)}".freeze
            m = gen.next_label
            erbout << "    goto L#{format("%04d", m)};\nL#{format("%04d", l)}:;\n".freeze

            if gen.location
              erbout << "    ctx->position_offset_loc = p_loc;\n".freeze
            end
            erbout << "    ctx->position_offset = p;\n    packcr_thunk_array__revert(ctx->auxil, &chunk->thunks, n);\nL#{format("%04d", m)}:;\n}\n".freeze
          end
          erbout
        when :rb
          erbout = +""
          r = expr.reachability
          if r == Packcr::CODE_REACH__ALWAYS_SUCCEED

            erbout << "#{gen.generate_code(expr, nil, 0, true)}".freeze
          else
            l = gen.next_label
            erbout << "pos#{gen.level} = @position_offset\n".freeze

            if gen.location
              erbout << "p_loc#{gen.level} = @position_offset_loc\n".freeze
            end
            erbout << "n#{gen.level} = answer.thunks.length\n".freeze

            m = gen.next_label
            erbout << "catch(#{m}) do\n  catch(#{l}) do\n#{gen.generate_code(expr, l, 4, false)}    throw(#{m})\n  end\n".freeze

            if gen.location
              erbout << "  @position_offset_loc = p_loc#{gen.level}\n".freeze
            end
            erbout << "  @position_offset = pos#{gen.level}\n  answer.thunks[n#{gen.level}..-1] = []\nend\n".freeze
          end
          erbout
        when :rs
          erbout = +""
          r = expr.reachability
          if r == Packcr::CODE_REACH__ALWAYS_SUCCEED
            erbout << "#{gen.generate_code(expr, nil, 0, true)}".freeze
          else
            erbout << "let p = self.input.position_offset;\n".freeze

            l = gen.next_label
            if expr.reversible?(gen)
              erbout << "catch(#{l}, || {\n    #{gen.generate_code(expr, l, 4, false, reverse: true)}    self.input.position_offset = p;\n    NOP\n})?;\n".freeze

            else
              m = gen.next_label
              erbout << "catch(#{m}, || {\n    catch(#{l}, || {\n        #{gen.generate_code(expr, l, 8, false)}        return throw(#{m});\n    })?;\n    self.input.position_offset = p;\n    NOP\n})?;\n".freeze
            end
          end
          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end
    end
  end
end
