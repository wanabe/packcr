class Packcr
  class Node
    class CaptureNode
      def get_code(gen, onfail, indent, unwrap, oncut)
        case gen.lang
        when :c
          erbout = +""
          erbout << "{\n    const size_t p = ctx->position_offset;\n    size_t q;\n".freeze

          if gen.location
            erbout << "    packcr_location_t p_loc = ctx->position_offset_loc;\n    packcr_location_t q_loc;\n".freeze
          end
          erbout << "#{gen.generate_code(expr, onfail, 4, false)}    q = ctx->position_offset;\n    chunk->capts.buf[#{index}].range.start = p;\n    chunk->capts.buf[#{index}].range.end = q;\n".freeze

          if gen.location
            erbout << "    q_loc = ctx->position_offset_loc;\n    chunk->capts.buf[#{index}].range.start_loc = p_loc;\n    chunk->capts.buf[#{index}].range.end_loc = q_loc;\n".freeze
          end
          erbout << "}\n".freeze

          erbout
        when :rb
          erbout = +""
          erbout << "pos#{gen.level} = @position_offset\n".freeze

          if gen.location
            erbout << "p_loc#{gen.level} = @position_offset_loc\n".freeze
          end

          erbout << "#{gen.generate_code(expr, onfail, 0, false)}q#{gen.level} = @position_offset\ncapt#{gen.level} = answer.capts[#{index}]\ncapt#{gen.level}.range_start = pos#{gen.level}\ncapt#{gen.level}.range_end = q#{gen.level}\n".freeze

          if gen.location
            erbout << "q_loc#{gen.level} = @position_offset_loc\ncapt#{gen.level}.start_loc = p_loc#{gen.level}\ncapt#{gen.level}.end_loc = q_loc#{gen.level}\n".freeze
          end
          erbout
        when :rs
          erbout = +""
          erbout << "let p_inner = self.input.position_offset;\n".freeze

          if gen.location
            erbout << "TODO\n".freeze
          end
          erbout << "{\n#{gen.generate_code(expr, onfail, 4, false)}}\nlet q = self.input.position_offset;\nanswer.capts[#{index}].start = p_inner;\nanswer.capts[#{index}].end = q;\n".freeze

          if gen.location
            erbout << "TODO\n".freeze
          end
          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end
    end
  end
end
