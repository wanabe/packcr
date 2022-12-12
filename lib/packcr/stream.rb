class Packcr
  class Stream
    def initialize(io, name, line)
      @io = io
      @name = name
      @line = line
    end

    def putc(c)
      @io.putc(c)
      if @line && c.chr == "\n"
        @line += 1
      end
    end

    def write_characters(c, n)
      n.times do
        putc(c)
      end
    end

    def write(s)
      @io.write(s)
      if @line
        @line += s.count("\n")
      end
    end

    def write_text(s)
      skip_char = nil

      s.each_byte do |c|
        if c == skip_char
          skip_char = nil
          next
        end
        skip_char = nil

        if c == 0xd
          skip_char = 0xa
          putc(0xa)
        else
          putc(c)
        end
      end
    end

    def write_line_directive(fname, lineno)
      return unless @line
      write("#line #{lineno + 1} \"")
      fname.each_byte do |b|
        write(Packcr.escape_character(b))
      end
      write("\"\n")
    end

    def write_output_line_directive
      write_line_directive(@name, @line)
    end

    def write_code_block(code, indent, fname)
      b = false
      i = j = k = nil
      text = code.text
      ptr = text.b
      len = code.len
      lineno = code.line
      if len == nil
        return # for safety
      end

      j, k = Packcr.find_first_trailing_space(ptr, 0, len)
      i = 0
      while i < j
        if ptr[i] != " " && ptr[i] != "\v" && ptr[i] != "\f" && ptr[i] != "\t"
          break
        end
        i += 1
      end
      if i < j
        write_line_directive(fname, lineno)
        if ptr[i] != "#"
          write " " * indent
        end
        write_text(ptr[i, j - i])
        putc "\n".ord
        b = true
      else
        lineno += 1
      end
      if k < len
        m = nil
        i = k
        while i < len
          j, h = Packcr.find_first_trailing_space(ptr, i, len)
          if i < j
            if !b
              write_line_directive(fname, lineno)
            end
            if ptr[i] != "#"
              l, = Packcr.count_indent_spaces(ptr, i, j)
              if m == nil || m > l
                m = l
              end
            end
            b = true
          elsif !b
            k = h
            lineno += 1
          end
          i = h
        end

        i = k
        while i < len
          j, h = Packcr.find_first_trailing_space(ptr, i, len)
          if i < j
            l, i = Packcr.count_indent_spaces(ptr, i, j)
            if ptr[i] != "#"
              if m == nil
                raise "m must have a valid value"
              end
              unless l >= m
                raise "invalid l:#{l}, m:#{m}"
              end
              write " " * (l - m + indent)
            end
            write_text(ptr[i, j - i])
            putc "\n"
            b = true
          elsif h < len
            putc "\n"
          end
          i = h
        end
      end
      if b
        write_output_line_directive
      end
    end
  end
end