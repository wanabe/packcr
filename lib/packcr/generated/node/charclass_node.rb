class Packcr
  class Node
    class CharclassNode
      def get_code(gen, onfail, indent, unwrap, charclass, n, a)
        case gen.lang
        when :c
          erbout = +""
          erbout << "{\n    char c;\n    if (packcr_refill_buffer(ctx, 1) < 1) goto L#{format("%04d", onfail)};\n    c = ctx->buffer.buf[ctx->position_offset];\n".freeze
          if !a && charclass =~ /\A[^\\]-.\z/

            if a
              erbout << "    if (c >= '#{Packcr.escape_character(charclass[0])}' && c <= '#{Packcr.escape_character(charclass[2])}') goto L#{format("%04d", onfail)};\n".freeze

            else
              erbout << "    if (!(c >= '#{Packcr.escape_character(charclass[0])}' && c <= '#{Packcr.escape_character(charclass[2])}')) goto L#{format("%04d", onfail)};\n".freeze
            end

          else

            if a
              erbout << "    if (\n".freeze

            else
              erbout << "    if (!(\n".freeze
            end
            i = 0
            while i < n
              if charclass[i] == "\\" && i + 1 < n
                i += 1
              end
              if i + 2 < n && charclass[i + 1] == "-"
                erbout << "        (c >= '#{Packcr.escape_character(charclass[i])}' && c <= '#{Packcr.escape_character(charclass[i + 2])}')#{i + 3 == n ? "" : " ||"}\n".freeze

                i += 2
              else
                erbout << "        c == '#{Packcr.escape_character(charclass[i])}'#{i + 1 == n ? "" : " ||"}\n".freeze
              end
              i += 1
            end
            if a
              erbout << "    ) goto L#{format("%04d", onfail)};\n".freeze

            else
              erbout << "    )) goto L#{format("%04d", onfail)};\n".freeze
            end
          end
          if gen.location
            erbout << "    packcr_location_forward(&ctx->position_offset_loc, ctx->buffer.buf + ctx->position_offset, 1);\n".freeze
          end
          erbout << "    ctx->position_offset++;\n}\n".freeze

          erbout
        when :rb
          erbout = +""
          erbout << "if refill_buffer(1) < 1\n  throw(#{onfail})\nend\nc#{gen.level} = @buffer[@position_offset]\n".freeze
          if !a && charclass =~ /\A[^\\]-.\z/

            if a
              erbout << "if c#{gen.level} >= \"#{Packcr.escape_character(charclass[0])}\" && c#{gen.level} <= \"#{Packcr.escape_character(charclass[2])}\"\n  throw(#{onfail})\nend\n".freeze

            else
              erbout << "unless c#{gen.level} >= \"#{Packcr.escape_character(charclass[0])}\" && c#{gen.level} <= \"#{Packcr.escape_character(charclass[2])}\"\n  throw(#{onfail})\nend\n".freeze
            end

          else

            if a
              erbout << "if (\n".freeze

            else
              erbout << "unless (\n".freeze
            end
            i = 0
            while i < n
              if charclass[i] == "\\" && i + 1 < n
                i += 1
              end
              if i + 2 < n && charclass[i + 1] == "-"
                erbout << "  (c#{gen.level} >= \"#{Packcr.escape_character(charclass[i])}\" && c#{gen.level} <= \"#{Packcr.escape_character(charclass[i + 2])}\")#{i + 3 == n ? "" : " ||"}\n".freeze

                i += 2
              else
                erbout << "  c#{gen.level} == \"#{Packcr.escape_character(charclass[i])}\"#{i + 1 == n ? "" : " ||"}\n".freeze
              end
              i += 1
            end
            erbout << ")\n  throw(#{onfail})\nend\n".freeze

          end
          if gen.location
            erbout << "@position_offset_loc = @position_offset_loc.forward(@buffer, @position_offset, 1)\n".freeze
          end
          erbout << "@position_offset += 1\n".freeze
          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end

      def get_any_code(gen, onfail, indent, unwrap, charclass)
        case gen.lang
        when :c
          erbout = +""
          erbout << "if (packcr_refill_buffer(ctx, 1) < 1) goto L#{format("%04d", onfail)};\n".freeze

          if gen.location
            erbout << "packcr_location_forward(&ctx->position_offset, ctx->buffer.buf + ctx->position_offset, 1);\n".freeze
          end
          erbout << "ctx->position_offset++;\n".freeze

          erbout
        when :rb
          erbout = +""
          erbout << "if refill_buffer(1) < 1\n  throw(#{onfail})\nend\n".freeze

          if gen.location
            erbout << "@position_offset_loc = @position_offset_loc.forward(@buffer, @position_offset, 1)\n".freeze
          end
          erbout << "@position_offset += 1\n".freeze

          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end

      def get_fail_code(gen, onfail, indent, unwrap)
        case gen.lang
        when :c
          erbout = +""
          erbout << "goto L#{format("%04d", onfail)};\n".freeze

          erbout
        when :rb
          erbout = +""
          erbout << "throw(#{onfail})\n".freeze

          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end

      def get_one_code(gen, onfail, indent, unwrap, charclass, n, a)
        case gen.lang
        when :c
          erbout = +""
          if a
            erbout << "if (\n    packcr_refill_buffer(ctx, 1) < 1 ||\n    ctx->buffer.buf[ctx->position_offset] == '#{Packcr.escape_character(charclass[i])}'\n) goto L#{format("%04d", onfail)};\n".freeze

          else
            erbout << "if (\n    packcr_refill_buffer(ctx, 1) < 1 ||\n    ctx->buffer.buf[ctx->position_offset] != '#{Packcr.escape_character(charclass[0])}'\n) goto L#{format("%04d", onfail)};\n".freeze

          end
          if gen.location
            erbout << "    packcr_location_forward(&ctx->position_offset_loc, ctx->buffer.buf + ctx->position_offset, 1);\n".freeze
          end
          erbout << "ctx->position_offset++;\n".freeze
          erbout
        when :rb
          erbout = +""
          if a
            erbout << "if (\n  refill_buffer(1) < 1 ||\n  @buffer[@position_offset] == \"#{Packcr.escape_character(charclass[0])}\"\n)\n  throw(#{onfail})\nend\n".freeze

          else
            erbout << "if (\n  refill_buffer(1) < 1 ||\n  @buffer[@position_offset] != \"#{Packcr.escape_character(charclass[0])}\"\n)\n  throw(#{onfail})\nend\n".freeze

          end
          if gen.location
            erbout << "@position_offset_loc = @position_offset_loc.forward(@buffer, @position_offset, 1)\n".freeze
          end
          erbout << "@position_offset += 1\n".freeze
          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end

      def get_utf8_code(gen, onfail, indent, unwrap, charclass, n)
        case gen.lang
        when :c
          erbout = +""
          a = charclass && charclass[0] == "^"
          i = a ? 1 : 0
          erbout << "{\n    int u;\n    const size_t n = packcr_get_char_as_utf32(ctx, &u);\n    if (n == 0) goto L#{format("%04d", onfail)};\n".freeze

          if charclass && !(a && n == 1) # not '.' or '[^]'
            u0 = 0
            r = false
            if a
              erbout << "    if (\n".freeze

            else
              erbout << "    if (!(\n".freeze
            end
            while i < n
              if charclass[i] == "\\" && i + 1 < n
                i += 1
              end
              u = charclass[i].ord
              i += 1
              if r
                # character range
                erbout << "        (u >= 0x#{format("%06x", u0)} && u <= 0x#{format("%06x", u)})".freeze
                if i < n
                  erbout << " ||".freeze
                end
                erbout << "\n".freeze

                u0 = 0
                r = false
              elsif charclass[i] != "-" || i == n - 1 # the individual '-' character is valid when it is at the first or the last position
                # single character
                erbout << "        u == 0x#{format("%06x", u)}".freeze
                if i < n
                  erbout << " ||".freeze
                end
                erbout << "\n".freeze

                u0 = 0
                r = false
              elsif charclass[i] == "-"
                i += 1
                u0 = u
                r = true
              else
                raise "unexpected charclass #{charclass[i]}"
              end
            end
            if a
              erbout << "    ) goto L#{format("%04d", onfail)};\n".freeze

            else
              erbout << "    )) goto L#{format("%04d", onfail)};\n".freeze
            end
          end
          if gen.location
            erbout << "    packcr_location_forward(&ctx->position_offset_loc, ctx->buffer.buf + ctx->position_offset, n);\n".freeze
          end
          erbout << "    ctx->position_offset += n;\n}\n".freeze

          erbout
        when :rb
          erbout = +""
          a = charclass && charclass[0] == "^"
          i = a ? 1 : 0
          erbout << "if refill_buffer(1) < 1\n  throw(#{onfail})\nend\nu#{gen.level} = @buffer[@position_offset]\n".freeze

          if charclass && !(a && n == 1) # not '.' or '[^]'
            u0 = nil
            r = false
            if a
              erbout << "if (\n".freeze

            else
              erbout << "if (!(\n".freeze
            end
            while i < n
              if charclass[i] == "\\" && i + 1 < n
                i += 1
              end
              u = charclass[i]
              i += 1
              if r
                # character range
                erbout << "  (u#{gen.level} >= #{u0.dump} && u#{gen.level} <= #{u.dump})".freeze
                if i < n
                  erbout << " ||".freeze
                end
                erbout << "\n".freeze

                u0 = 0
                r = false
              elsif charclass[i] != "-" || i == n - 1 # the individual '-' character is valid when it is at the first or the last position
                # single character
                erbout << "  u#{gen.level} == #{u.dump}".freeze
                if i < n
                  erbout << " ||".freeze
                end
                erbout << "\n".freeze

                u0 = 0
                r = false
              elsif charclass[i] == "-"
                i += 1
                u0 = u
                r = true
              else
                raise "unexpected charclass #{charclass[i]}"
              end
            end
            if a
              erbout << ")\n".freeze

            else
              erbout << "))\n".freeze
            end
            erbout << "  throw(#{onfail})\nend\n".freeze
          end
          if gen.location
            erbout << "@position_offset_loc = @position_offset_loc.forward(@buffer, @position_offset, 1)\n".freeze
          end
          erbout << "@position_offset += 1\n".freeze

          erbout
        when :rs
          erbout = +""
          a = charclass && charclass[0] == "^"
          i = a ? 1 : 0
          any_code = !charclass || (a && n == 1)
          erbout << "let (#{any_code ? "_" : ""}u, n) = self.input.get_char_as_utf32();\nif n == 0 {\n    return throw(#{onfail});\n}\n".freeze

          unless any_code
            erbout << "if ".freeze
            if !a

              erbout << "!(".freeze
            end
            while i < n
              if charclass[i] == "\\" && i + 1 < n
                i += 1
              end
              u = charclass[i].ord
              i += 1
              if r
                # character range

                erbout << "(0x#{format("%06x", u0)}..=0x#{format("%06x", u)}).contains(&u)".freeze

                if i < n
                  erbout << " || ".freeze
                end
                u0 = 0
                r = false
              elsif charclass[i] != "-" || i == n - 1 # the individual '-' character is valid when it is at the first or the last position
                # single character

                erbout << "u == 0x#{format("%06x", u)}".freeze
                if i < n
                  erbout << " || ".freeze
                end
                u0 = 0
                r = false
              elsif charclass[i] == "-"
                i += 1
                u0 = u
                r = true
              else
                raise "unexpected charclass #{charclass[i]}"
              end
            end
            if !a
              erbout << ") ".freeze
            end

            erbout << "{\n    return throw(#{onfail});\n}\n".freeze
          end
          erbout << "self.input.forward(n);\n".freeze

          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end

      def get_utf8_reverse_code(gen, onsuccess, indent, unwrap, charclass, n)
        case gen.lang
        when :rb
          erbout = +""
          a = charclass && charclass[0] == "^"
          i = a ? 1 : 0
          erbout << "if refill_buffer(1) >= 1\n  u#{gen.level} = @buffer[@position_offset]\n".freeze

          if charclass && !(a && n == 1) # not '.' or '[^]'
            u0 = nil
            r = false
            if a
              erbout << "  unless (\n".freeze

            else
              erbout << "  if (\n".freeze
            end
            while i < n
              if charclass[i] == "\\" && i + 1 < n
                i += 1
              end
              u = charclass[i]
              i += 1
              if r
                # character range
                erbout << "    (u#{gen.level} >= #{u0.dump} && u#{gen.level} <= #{u.dump})".freeze
                if i < n
                  erbout << " ||".freeze
                end
                erbout << "\n".freeze

                u0 = 0
                r = false
              elsif charclass[i] != "-" || i == n - 1 # the individual '-' character is valid when it is at the first or the last position
                # single character
                erbout << "    u#{gen.level} == #{u.dump}".freeze
                if i < n
                  erbout << " ||".freeze
                end
                erbout << "\n".freeze

                u0 = 0
                r = false
              elsif charclass[i] == "-"
                i += 1
                u0 = u
                r = true
              else
                raise "unexpected charclass #{charclass[i]}"
              end
            end
            erbout << "  )\n".freeze

            if gen.location
              erbout << "    @position_offset_loc = @position_offset_loc.forward(@buffer, @position_offset, 1)\n".freeze
            end
            erbout << "    @position_offset += 1\n    throw(#{onsuccess})\n  end\n".freeze

          else # '.' or '[^]'
            if gen.location
              erbout << "  @position_offset_loc = @position_offset_loc.forward(@buffer, @position_offset, 1)\n".freeze
            end
            erbout << "  @position_offset += 1\n  throw(#{onsuccess})\n".freeze
          end
          erbout << "end\n".freeze

          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end
    end
  end
end
