class Packcr
  CODE_REACH__BOTH = 0
  CODE_REACH__ALWAYS_SUCCEED = 1
  CODE_REACH__ALWAYS_FAIL = -1

  def initialize(path, **opt)
    @path = path.to_s
    @opt = opt
  end

  def run
    Context.new(@path.to_s, **@opt) do |ctx|
      if !ctx.parse || !ctx.generate
        raise "PackCC error"
      end
    end
  end

  class << self
    def escape_character(c)
      ch = c.ord
      case ch
      when 0x00
        "\\0"
      when 0x07
        "\\a"
      when 0x08
        "\\b"
      when 0x0c
        "\\f"
      when 0x0a
        "\\n"
      when 0x0d
        "\\r"
      when 0x09
        "\\t"
      when 0x0b
        "\\v"
      when "\\".ord
        "\\\\"
      when "\'".ord
        "\\\'"
      when "\"".ord
        "\\\""
      else
        if ch >= 0x20 && ch < 0x7f
          ch.chr
        else
          "\\x%02x" % ch
        end
      end
    end
  end
end

class Packcr::Stream
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
    write("#line #{lineno + 1} \"")
    fname.each_byte do |b|
      write(Packcr.escape_character(b))
    end
    write("\"\n")
  end
end

class Packcr::Generator
  def initialize(stream, rule, ascii)
    @stream = stream
    @rule = rule
    @label = 0
    @ascii = !!ascii
  end

  def next_label
    @label += 1
  end

  def generate_matching_string_code(value, onfail, indent, bare)
    n = value&.length || 0

    if n > 0
      if n > 1
        @stream.write " " * indent
        @stream.write "if (\n"
        @stream.write " " * (indent + 4)
        @stream.write "pcc_refill_buffer(ctx, #{n}) < #{n} ||\n"
        (n - 1).times do |i|
          @stream.write " " * (indent + 4)
          s = Packcr.escape_character(value[i])
          @stream.write "(ctx->buffer.buf + ctx->cur)[#{i}] != '#{s}' ||\n"
        end
        @stream.write " " * (indent + 4)
        s = Packcr.escape_character(value[n - 1])
        @stream.write "(ctx->buffer.buf + ctx->cur)[#{n - 1}] != '#{s}'\n"
        @stream.write " " * indent
        @stream.write ") goto L#{"%04d" % onfail};\n"
        @stream.write " " * indent
        @stream.write "ctx->cur += #{n};\n"
        return Packcr::CODE_REACH__BOTH
      else
        @stream.write " " * indent
        @stream.write "if (\n"
        @stream.write " " * (indent + 4)
        @stream.write "pcc_refill_buffer(ctx, 1) < 1 ||\n"
        @stream.write " " * (indent + 4)
        s = Packcr.escape_character(value[0])
        @stream.write "ctx->buffer.buf[ctx->cur] != '#{s}'\n"
        @stream.write " " * indent
        @stream.write ") goto L#{"%04d" % onfail};\n"
        @stream.write " " * indent
        @stream.write "ctx->cur++;\n"
        return Packcr::CODE_REACH__BOTH
      end
    else
      # no code to generate
      return Packcr::CODE_REACH__ALWAYS_SUCCEED
    end
  end

  def generate_matching_charclass_code(charclass, onfail, indent, bare)
    if !@ascii
      raise "unexpected calling #generate_matching_charclass_code on no-ascii mode"
    end

    if charclass
      n = charclass.length
      if n > 0
        if n > 1
          a = charclass[0] == "^"
          i = a ? 1 : 0
          if i + 1 == n # fulfilled only if a == true
            @stream.write " " * indent
            @stream.write "if (\n"
            @stream.write " " * (indent + 4)
            @stream.write "pcc_refill_buffer(ctx, 1) < 1 ||\n"
            @stream.write " " * (indent + 4)
            @stream.write "ctx->buffer.buf[ctx->cur] == '#{Packcr.escape_character(charclass[i])}'\n"
            @stream.write " " * indent
            @stream.write ") goto L#{"%04d" % onfail};\n"
            @stream.write " " * indent
            @stream.write "ctx->cur++;\n"
            return Packcr::CODE_REACH__BOTH
          else
            if !bare
              @stream.write " " * indent
              @stream.write "{\n"
              indent += 4
            end
            @stream.write " " * indent
            @stream.write "char c;\n"
            @stream.write " " * indent
            @stream.write "if (pcc_refill_buffer(ctx, 1) < 1) goto L#{"%04d" % onfail};\n"
            @stream.write " " * indent
            @stream.write "c = ctx->buffer.buf[ctx->cur];\n"
            if i + 3 == n && charclass[i] != "\\" && charclass[i + 1] == "-"
              @stream.write " " * indent
              s = Packcr.escape_character(charclass[i])
              t = Packcr.escape_character(charclass[i + 2])
              if a
                @stream.write "if (c >= '#{s}' && c <= '#{t}') goto L#{"%04d" % onfail};\n"
              else
                @stream.write "if (!(c >= '#{s}' && c <= '#{t}')) goto L#{"%04d" % onfail};\n"
              end
            else
              @stream.write " " * indent
              @stream.write a ? "if (\n" : "if (!(\n"
              while i < n
                @stream.write " " * (indent + 4)
                if charclass[i] == "\\" && i + 1 < n
                  i += 1
                end
                if i + 2 < n && charclass[i + 1] == '-'
                  s = Packcr.escape_character(charclass[i])
                  t = Packcr.escape_character(charclass[i + 2])
                  @stream.write "(c >= '#{s}' && c <= '#{t}')#{(i + 3 == n) ? "" : " ||"}\n"
                  i += 2
                else
                  s = Packcr.escape_character(charclass[i])
                  @stream.write "c == '#{s}'#{(i + 1 == n) ? "" : " ||"}\n"
                end
                i += 1
              end
              @stream.write " " * indent
              @stream.write a ? ") goto L#{"%04d" % onfail};\n" : ")) goto L#{"%04d" % onfail};\n"
            end
            @stream.write " " * indent
            @stream.write "ctx->cur++;\n"
            if !bare
              indent -= 4
              @stream.write " " * indent
              @stream.write "}\n"
            end
            return Packcr::CODE_REACH__BOTH
          end
        else
          s = Packcr.escape_character(charclass[0])
          @stream.write " " * indent
          @stream.write "if (\n"
          @stream.write " " * (indent + 4)
          @stream.write "pcc_refill_buffer(ctx, 1) < 1 ||\n"
          @stream.write " " * (indent + 4)
          @stream.write "ctx->buffer.buf[ctx->cur] != '#{s}'\n"
          @stream.write " " * indent
          @stream.write ") goto L#{"%04d" % onfail};\n"
          @stream.write " " * indent
          @stream.write "ctx->cur++;\n"
          return Packcr::CODE_REACH__BOTH
        end
      else
        @stream.write " " * indent
        @stream.write "goto L#{"%04d" % onfail};\n"
        return Packcr::CODE_REACH__ALWAYS_FAIL
      end
    else
      @stream.write " " * indent
      @stream.write "if (pcc_refill_buffer(ctx, 1) < 1) goto L#{"%04d" % onfail};\n"
      @stream.write " " * indent
      @stream.write "ctx->cur++;\n"
      return Packcr::CODE_REACH__BOTH
    end
  end

  def generate_matching_utf8_charclass_code(charclass, onfail, indent, bare)
    if charclass && charclass.encoding != Encoding::UTF_8
      charclass = charclass.dup.force_encoding(Encoding::UTF_8)
    end
    n = charclass&.length || 0
    if charclass.nil? || n > 0
      a = charclass && charclass[0] == '^'
      i = a ? 1 : 0
      if !bare
        @stream.write " " * indent
        @stream.write "{\n"
        indent += 4
      end
      @stream.write " " * indent
      @stream.write "int u;\n"
      @stream.write " " * indent
      @stream.write "const size_t n = pcc_get_char_as_utf32(ctx, &u);\n"
      @stream.write " " * indent
      @stream.write "if (n == 0) goto L#{"%04d" % onfail};\n"
      if charclass && !(a && n == 1) # not '.' or '[^]'
        u0 = 0
        r = false
        @stream.write " " * indent
        @stream.write a ? "if (\n" : "if (!(\n"
        while i < n
          u = 0
          if charclass[i] == '\\' && i + 1 < n
            i += 1
          end
          u = charclass[i].ord
          i += 1
          if r
            # character range
            @stream.write " " * (indent + 4)
            @stream.write "(u >= 0x#{"%06x" % u0 } && u <= 0x#{"%06x" % u})#{(i < n) ? " ||" : ""}\n"
            u0 = 0
            r = false
          elsif charclass[i] != "-" || i == n - 1 # the individual '-' character is valid when it is at the first or the last position
            # single character
            @stream.write " " * (indent + 4)
            @stream.write "u == 0x#{"%06x" % u}#{(i < n) ? " ||" : ""}\n"
            u0 = 0
            r = false
          else
            unless charclass[i] == "-"
              raise "unexpected charclass #{charclass[i]}"
            end
            i += 1
            u0 = u
            r = true
          end
        end
        @stream.write " " * indent
        @stream.write a ? ") goto L#{"%04d" % onfail};\n" : ")) goto L#{"%04d" % onfail};\n"
      end
      @stream.write " " * indent
      @stream.write "ctx->cur += n;\n"
      if !bare
        indent -= 4
        @stream.write " " * indent
        @stream.write "}\n"
      end
      return Packcr::CODE_REACH__BOTH
    else
      @stream.write " " * indent
      @stream.write "goto L#{"%04d" % onfail};\n"
      return Packcr::CODE_REACH__ALWAYS_FAIL
    end
  end

  def generate_quantifying_code(expr, min, max, onfail, indent, bare)
    if max > 1 || max < 0
      if !bare
        @stream.write " " * indent
        @stream.write "{\n"
        indent += 4
      end

      if min > 0
        @stream.write " " * indent
        @stream.write "const size_t p0 = ctx->cur;\n"
        @stream.write " " * indent
        @stream.write "const size_t n0 = chunk->thunks.len;\n"
      end
      @stream.write " " * indent
      @stream.write "int i;\n"
      @stream.write " " * indent

      if max < 0
        @stream.write "for (i = 0;; i++) {\n"
      else
        @stream.write "for (i = 0; i < #{max}; i++) {\n"
      end
      @stream.write " " * (indent + 4)
      @stream.write "const size_t p = ctx->cur;\n"
      @stream.write " " * (indent + 4)
      @stream.write "const size_t n = chunk->thunks.len;\n"

      l = next_label
      r = generate_code(expr, l, indent + 4, false)
      @stream.write " " * (indent + 4)
      @stream.write "if (ctx->cur == p) break;\n"
      if r !=Packcr::CODE_REACH__ALWAYS_SUCCEED
        @stream.write " " * (indent + 4)
        @stream.write "continue;\n"
        @stream.write " " * indent
        @stream.write "L#{"%04d" % l}:;\n"
        @stream.write " " * (indent + 4)
        @stream.write "ctx->cur = p;\n"
        @stream.write " " * (indent + 4)
        @stream.write "pcc_thunk_array__revert(ctx->auxil, &chunk->thunks, n);\n"
        @stream.write " " * (indent + 4)
        @stream.write "break;\n"
      end

      @stream.write " " * indent
      @stream.write "}\n"

      if min > 0
        @stream.write " " * indent
        @stream.write "if (i < #{min}) {\n"
        @stream.write " " * (indent + 4)
        @stream.write "ctx->cur = p0;\n"
        @stream.write " " * (indent + 4)
        @stream.write "pcc_thunk_array__revert(ctx->auxil, &chunk->thunks, n0);\n"
        @stream.write " " * (indent + 4)
        @stream.write "goto L#{"%04d" % onfail};\n"
        @stream.write " " * indent
        @stream.write "}\n"
      end
      if !bare
        indent -= 4
        @stream.write " " * indent
        @stream.write "}\n"
      end
      if min > 0
        return r ==Packcr::CODE_REACH__ALWAYS_FAIL ? Packcr::CODE_REACH__ALWAYS_FAIL : Packcr::CODE_REACH__BOTH
      else
        return Packcr::CODE_REACH__ALWAYS_SUCCEED
      end
    elsif max == 1
      if min > 0
        return generate_code(expr, onfail, indent, bare)
      else
        if !bare
          @stream.write " " * indent
          @stream.write "{\n"
          indent += 4
        end
        @stream.write " " * indent
        @stream.write "const size_t p = ctx->cur;\n"
        @stream.write " " * indent
        @stream.write "const size_t n = chunk->thunks.len;\n"
        l = next_label
        if generate_code(expr, l, indent, false) != Packcr::CODE_REACH__ALWAYS_SUCCEED
          m = next_label
          @stream.write " " * indent
          @stream.write "goto L#{"%04d" % m};\n"
          if indent > 4
            @stream.write " " * (indent - 4)
          end
          @stream.write "L#{"%04d" % l}:;\n"
          @stream.write " " * indent
          @stream.write "ctx->cur = p;\n"
          @stream.write " " * indent
          @stream.write "pcc_thunk_array__revert(ctx->auxil, &chunk->thunks, n);\n"
          if indent > 4
            @stream.write " " * (indent - 4)
          end
          @stream.write "L#{"%04d" % m}:;\n"
        end

        if !bare
            indent -= 4
            @stream.write " " * indent
            @stream.write "}\n"
        end
        return Packcr::CODE_REACH__ALWAYS_SUCCEED
      end
    else
      # no code to generate
      return Packcr::CODE_REACH__ALWAYS_SUCCEED
    end
  end

  def generate_predicating_code(expr, neg, onfail, indent, bare)
    if !bare
      @stream.write " " * indent
      @stream.write "{\n"
      indent += 4
    end
    @stream.write " " * indent
    @stream.write "const size_t p = ctx->cur;\n"

    if neg
      l = next_label
      r = generate_code(expr, l, indent, false)

      if r != Packcr::CODE_REACH__ALWAYS_FAIL
        @stream.write " " * indent
        @stream.write "ctx->cur = p;\n"
        @stream.write " " * indent
        @stream.write "goto L#{"%04d" % onfail};\n"
      end
      if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
        if indent > 4
          @stream.write " " * (indent - 4)
        end
        @stream.write "L#{"%04d" % l}:;\n"
        @stream.write " " * indent
        @stream.write "ctx->cur = p;\n"
      end

      case r
      when Packcr::CODE_REACH__ALWAYS_SUCCEED
        r = Packcr::CODE_REACH__ALWAYS_FAIL
      when Packcr::CODE_REACH__ALWAYS_FAIL
        r = Packcr::CODE_REACH__ALWAYS_SUCCEED
      end
    else
      l = next_label
      m = next_label
      r = generate_code(expr, l, indent, false)
      if r != Packcr::CODE_REACH__ALWAYS_FAIL
        @stream.write " " * indent
        @stream.write "ctx->cur = p;\n"
      end
      if r == Packcr::CODE_REACH__BOTH
        @stream.write " " * indent
        @stream.write "goto L#{"%04d" % m};\n"
      end
      if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
        if indent > 4
          @stream.write " " * (indent - 4)
        end
        @stream.write "L#{"%04d" % l}:;\n"
        @stream.write " " * indent
        @stream.write "ctx->cur = p;\n"
        @stream.write " " * indent
        @stream.write "goto L#{"%04d" % onfail};\n"
      end
      if r == Packcr::CODE_REACH__BOTH
        if indent > 4
          @stream.write " " * (indent - 4)
        end
        @stream.write "L#{"%04d" % m}:;\n", m
      end
    end

    if !bare
      indent -= 4
      @stream.write " " * indent
      @stream.write "}\n"
    end
    return r
  end

  def generate_sequential_code(nodes, onfail, indent, bare)
    b = false
    nodes.each_with_index do |expr, i|
      case generate_code(expr, onfail, indent, false)
      when Packcr::CODE_REACH__ALWAYS_FAIL
        if i + 1 < rnodes.length
          @stream.write " " * indent
          @stream.write "/* unreachable codes omitted */\n"
        end
        return Packcr::CODE_REACH__ALWAYS_FAIL
      when Packcr::CODE_REACH__ALWAYS_SUCCEED
      else
        b = true
      end
    end
    return b ? Packcr::CODE_REACH__BOTH : Packcr::CODE_REACH__ALWAYS_SUCCEED
  end

  def generate_alternative_code(nodes, onfail, indent, bare)
    b = false
    m = next_label
    if !bare
      @stream.write " " * indent
      @stream.write "{\n"
      indent += 4
    end

    @stream.write " " * indent
    @stream.write "const size_t p = ctx->cur;\n"
    @stream.write " " * indent
    @stream.write "const size_t n = chunk->thunks.len;\n"

    nodes.each_with_index do |expr, i|
      c = i + 1 < nodes.length
      l = next_label
      case generate_code(expr, l, indent, false)
      when Packcr::CODE_REACH__ALWAYS_SUCCEED
        if c
          @stream.write " " * indent
          @stream.write "/* unreachable codes omitted */\n"
        end
        if b
          if indent > 4
            @stream.write " " * (indent - 4)
          end
          @stream.write "L#{"%04d" % m}:;\n"
        end
        if !bare
          indent -= 4
          @stream.write " " * indent
          @stream.write "}\n"
        end
        return Packcr::CODE_REACH__ALWAYS_SUCCEED
      when Packcr::CODE_REACH__ALWAYS_FAIL
      else
        b = true
        @stream.write " " * indent
        @stream.write "goto L#{"%04d" % m};\n"
      end

      if indent > 4
        @stream.write " " * (indent - 4)
      end
      @stream.write "L#{"%04d" % l}:;\n"
      @stream.write " " * indent
      @stream.write "ctx->cur = p;\n"
      @stream.write " " * indent
      @stream.write "pcc_thunk_array__revert(ctx->auxil, &chunk->thunks, n);\n"
      if !c
        @stream.write " " * indent
        @stream.write "goto L#{"%04d" % onfail};\n"
      end
    end
    if b
      if indent > 4
        @stream.write " " * (indent - 4)
      end
      @stream.write "L#{"%04d" % m}:;\n"
    end

    if !bare
      indent -= 4
      @stream.write " " * indent
      @stream.write "}\n"
    end
    b ? Packcr::CODE_REACH__BOTH : Packcr::CODE_REACH__ALWAYS_FAIL
  end

  def generate_capturing_code(expr, index, onfail, indent, bare)
    if !bare
      @stream.write " " * indent
      @stream.write "{\n"
      indent += 4
    end

    @stream.write " " * indent
    @stream.write "const size_t p = ctx->cur;\n"
    @stream.write " " * indent
    @stream.write "size_t q;\n"
    r = generate_code(expr, onfail, indent, false)
    @stream.write " " * indent
    @stream.write "q = ctx->cur;\n"
    @stream.write " " * indent
    @stream.write "chunk->capts.buf[#{index}].range.start = p;\n"
    @stream.write " " * indent
    @stream.write "chunk->capts.buf[#{index}].range.end = q;\n"

    if !bare
      indent -= 4
      @stream.write " " * indent
      @stream.write "}\n"
    end
    return r
  end

  def generate_expanding_code(index, onfail, indent, bare)
    if !bare
      @stream.write " " * indent
      @stream.write "{\n"
      indent += 4
    end
    @stream.write " " * indent
    @stream.write "const size_t n = chunk->capts.buf[#{index}].range.end - chunk->capts.buf[#{index}].range.start;\n"
    @stream.write " " * indent
    @stream.write "if (pcc_refill_buffer(ctx, n) < n) goto L#{"%04d" % onfail};\n"
    @stream.write " " * indent
    @stream.write "if (n > 0) {\n"
    @stream.write " " * (indent + 4)
    @stream.write "const char *const p = ctx->buffer.buf + ctx->cur;\n"
    @stream.write " " * (indent + 4)
    @stream.write "const char *const q = ctx->buffer.buf + chunk->capts.buf[#{index}].range.start;\n"
    @stream.write " " * (indent + 4)
    @stream.write "size_t i;\n"
    @stream.write " " * (indent + 4)
    @stream.write "for (i = 0; i < n; i++) {\n"
    @stream.write " " * (indent + 8)
    @stream.write "if (p[i] != q[i]) goto L#{"%04d" % onfail};\n"
    @stream.write " " * (indent + 4)
    @stream.write "}\n"
    @stream.write " " * (indent + 4)
    @stream.write "ctx->cur += n;\n"
    @stream.write " " * indent
    @stream.write "}\n"
    if !bare
        indent -= 4;
        @stream.write " " * indent
        @stream.write "}\n"
    end
    return Packcr::CODE_REACH__BOTH
  end

  def generate_thunking_action_code(index, vars, capts, error, onfail, indent, bare)
    if !bare
      @stream.write " " * indent
      @stream.write "{\n"
      indent += 4
    end
    if error
      @stream.write " " * indent
      @stream.write "pcc_value_t null;\n"
    end
    @stream.write " " * indent
    @stream.write "pcc_thunk_t *const thunk = pcc_thunk__create_leaf(ctx->auxil, pcc_action_#{@rule.name}_#{index}, #{@rule.vars.length}, #{@rule.capts.length});\n"

    vars.each do |var|
      @stream.write " " * indent
      @stream.write "thunk->data.leaf.values.buf[#{var.index}] = &(chunk->values.buf[#{var.index}]);\n"
    end
    capts.each do |capt|
      @stream.write " " * indent
      @stream.write "thunk->data.leaf.capts.buf[#{capt.index}] = &(chunk->capts.buf[#{capt.index}]);\n"
    end
    @stream.write " " * indent
    @stream.write "thunk->data.leaf.capt0.range.start = chunk->pos;\n"
    @stream.write " " * indent
    @stream.write "thunk->data.leaf.capt0.range.end = ctx->cur;\n"

    if error
      @stream.write " " * indent
      @stream.write "memset(&null, 0, sizeof(pcc_value_t /* in case */\n"
      @stream.write " " * indent
      @stream.write "thunk->data.leaf.action(ctx, thunk, &null);\n"
      @stream.write " " * indent
      @stream.write "pcc_thunk__destroy(ctx->auxil, thunk);\n"
    else
      @stream.write " " * indent
      @stream.write "pcc_thunk_array__add(ctx->auxil, &chunk->thunks, thunk);\n"
    end
    if !bare
      indent -= 4;
      @stream.write " " * indent
      @stream.write "}\n"
    end
    return Packcr::CODE_REACH__ALWAYS_SUCCEED
  end

  def generate_thunking_error_code(expr, index, vars, capts, onfail, indent, bare)
    l = next_label
    m = next_label
    if !bare
      @stream.write " " * indent
      @stream.write "{\n"
      indent += 4
    end
    r = generate_code(expr, l, indent, true)
    @stream.write " " * indent
    @stream.write "goto L#{"%04d" % m};\n"
    if indent > 4
      @stream.write " " * (indent - 4)
    end
    @stream.write "L#{"%04d" % l}:;\n"
    generate_thunking_action_code(index, vars, capts, true, l, indent, true)
    @stream.write " " * indent
    @stream.write "goto L#{"%04d" % onfail};\n"
    if indent > 4
      @stream.write " " * (indent - 4)
    end
    @stream.write "L%#{"04d" % m}:;\n"
    if !bare
      indent -= 4
      @stream.write " " * indent
      @stream.write "}\n"
    end
    return r
  end
end

class Packcr::Context
end

class Packcr::Buffer
  def initialize
    @buf = +"".b
  end

  def len
    @buf.length
  end

  def [](index)
    @buf[index].ord
  end

  def count_characters(s, e)
    # UTF-8 multibyte character support but without checking UTF-8 validity
    n = 0
    i = s
    while i < e
      c = self[i]
      if c == 0
        break
      end
      n += 1
      i += (c < 0x80) ? 1 : ((c & 0xe0) == 0xc0) ? 2 : ((c & 0xf0) == 0xe0) ? 3 : ((c & 0xf8) == 0xf0) ? 4 : 1
    end
    return n
  end

  def add(ch)
    @buf.concat(ch)
  end

  def to_s
    @buf
  end

  def []=(pos, ch)
    @buf[pos] = ch.chr
  end

  def add_pos(offset)
    @buf[0, offset] = ""
  end
end

require "packcr.so"

class Packcr::Node
  attr_reader :codes
  def initialize
    super
    @codes = []
  end
end

class Packcr::Context
  def init(path, lines: false, debug: false, ascii: false)
    @iname = path
    @ifile = File.open(path, "rb")
    dirname = File.dirname(path)
    basename = File.basename(path, ".*")
    if dirname == "."
      path = basename
    else
      path = File.join(dirname, basename)
    end
    @sname = path + ".c"
    @hname = path + ".h"
    @hid = File.basename(@hname).upcase.gsub(/[^A-Z0-9]/, "_")

    @lines = !!lines
    @debug = !!debug
    @ascii = !!ascii

    @errnum = 0
    @linenum = 0
    @charnum = 0
    @linepos = 0
    @bufpos = 0
    @bufcur = 0

    @esource = []
    @eheader = []
    @source = []
    @header = []
    @rules = []
    @rulehash = {}
    @buffer = Packcr::Buffer.new
  end

  def value_type
    @value_type || "int"
  end

  def auxil_type
    @auxil_type || "void *"
  end

  def prefix
    @prefix || "pcc"
  end

  def auxil_def
    type = auxil_type
    "#{type}#{type =~ /\*$/ ? "" : " "}"
  end

  def value_def
    type = value_type
    "#{type}#{type =~ /\*$/ ? "" : " "}"
  end

  def eof?
    refill_buffer(1) < 1
  end

  def eol?
    return false if eof?

    case @buffer[@bufcur]
    when 0xa
      @bufcur += 1
      @linenum += 1
      @charnum = 0
      @linepos = @bufpos + @bufcur
      true
    when 0xd
      @bufcur += 1
      if !eof? && @buffer[@bufcur] == 0xd
        @bufcur += 1
      end
      @linenum += 1
      @charnum = 0
      @linepos = @bufpos + @bufcur
      true
    else
      false
    end
  end

  def column_number
    unless @bufpos + @bufcur >= @linepos
      raise "invalid position: expect #{@bufpos + @bufcur} >= #{@linepos}"
    end
    offset = @linepos > @bufpos ? @linepos - @bufpos : 0
    if @ascii
      @charnum + @bufcur - offset
    else
      @charnum + @buffer.count_characters(offset, @bufcur)
    end
  end

  def make_rulehash
    @rules.each do |rule|
      @rulehash[rule.name] = rule
    end
  end

  def refill_buffer(num = nil)
    while !num || @buffer.len - @bufcur < num
      c = @ifile.getc
      break if c.nil?
      @buffer.add(c.ord)
    end

    return @buffer.len - @bufcur
  end

  def commit_buffer
    if @buffer.len < @bufcur
      raise "unexpected buffer state: length(#{@buffer.len}), current(#{@bufcur})"
    end
    if @linepos < @bufpos + @bufcur
	    count = @ascii ? @bufcur : @buffer.count_characters(0, @bufcur)
      @charnum += count
    end
    @buffer.add_pos(@bufcur)
    @bufpos = @bufpos + @bufcur
    @bufcur = 0
  end

  def write_buffer(stream)
    n = @buffer.len
    text = @buffer.to_s
    if n > 0 && text[-1] == "\r"
      text = text[0..-2]
    end
    stream.write_text(text)
    @bufcur = n
  end

  def match_character(ch)
    if refill_buffer(1) >= 1
      if @buffer[@bufcur].ord == ch
        @bufcur += 1
        return true
      end
    end
    false
  end

  def match_character_range(min, max)
    if refill_buffer(1) >= 1
      c = @buffer[@bufcur].ord
      if (min..max) === c
        @bufcur += 1
        return true
      end
    end
    false
  end

  def match_character_set(chars)
    if refill_buffer(1) >= 1
      c = @buffer[@bufcur].ord
      chars.each_byte do |ch|
        if c == ch
          @bufcur += 1
          return true
        end
      end
    end
    false
  end

  def match_string(str)
    n = str.length
    if refill_buffer(n) >= n
      if @buffer.to_s[@bufcur, n] == str
        @bufcur += n
        return true
      end
    end
    false
  end

  def match_blank
    match_character_set(" \t\v\f")
  end

  def match_character_any
    if refill_buffer(1) >= 1
      @bufcur += 1
      return true
    end
    false
  end

  def match_section_line_(head)
    if match_string(head)
      while !eol? && !eof?
        match_character_any
      end
      return true
    end
    false
  end

  def match_section_line_continuable_(head)
    if match_string(head)
      while !eof?
        pos = @bufcur
        if eol?
          if @buffer[pos - 1] != "\\".ord
            break
          end
        else
          match_character_any
        end
      end
      return true
    end
    false
  end

  def match_section_block_(left, right, name)
    l = @linenum
    m = column_number
    if match_string(left)
      while !match_string(right)
        if eof?
          warn "#{@iname}:#{l + 1}:#{m + 1}: Premature EOF in #{name}\n"
          @errnum += 1
          break
        end
        if !eol?
          match_character_any
        end
      end
      return true
    end
    false
  end

  def match_quotation_(left, right, name)
    l = @linenum
    m = column_number
    if match_string(left)
      while !match_string(right)
        if eof?
          warn "#{@iname}:#{l + 1}:#{m + 1}: Premature EOF in #{name}\n"
          @errnum += 1
          break
        end
        if match_character("\\".ord)
          if !eol?
            match_character_any
          end
        else
          if eol?
            warn "#{@iname}:#{l + 1}:#{m + 1}: Premature EOF in #{name}\n"
            @errnum += 1
            break
          end
          match_character_any
        end
      end
      return true
    end
    false
  end

  def match_directive_c
    match_section_line_continuable_("#")
  end

  def match_comment
    match_section_line_("#")
  end

  def match_comment_c
    match_section_block_("/*", "*/", "C comment")
  end

  def match_comment_cxx
    match_section_line_("//")
  end

  def match_quotation_single
    match_quotation_("\'", "\'", "single quotation")
  end

  def match_quotation_double
    match_quotation_("\"", "\"", "double quotation")
  end

  def match_character_class
    match_quotation_("[", "]", "character class")
  end

  def match_spaces
    n = 0
    while match_blank || eol? || match_comment
      n += 1
    end
    n > 0
  end

  def match_number
    if match_character_range("0".ord, "9".ord)
      while match_character_range("0".ord, "9".ord)
        return true
      end
    end
    return false
  end

  def generate
    File.open(@hname, "wt") do |hio|
      hstream = ::Packcr::Stream.new(hio, @hname, @lines ? 0 : nil)

      hstream.write "/* A packrat parser generated by PackCR %s */\n\n" %  ::Packcr::VERSION

      @eheader.each do |code|
        hstream.write_code_block(code, 0, @iname)
      end
      hstream.write "\n" if !@eheader.empty?

      hstream.write(<<~EOS)
        #ifndef PCC_INCLUDED_#{@hid}
        #define PCC_INCLUDED_#{@hid}

      EOS

      @header.each do |code|
        hstream.write_code_block(code, 0, @iname)
      end

      hstream.write(<<~EOS)
        #ifdef __cplusplus
        extern "C" {
        #endif

        typedef struct #{prefix}_context_tag #{prefix}_context_t;

        #{prefix}_context_t *#{prefix}_create(#{auxil_def}auxil);
        int #{prefix}_parse(#{prefix}_context_t *ctx, #{value_def}*ret);
        void #{prefix}_destroy(#{prefix}_context_t *ctx);

        #ifdef __cplusplus
        }
        #endif

        #endif /* !PCC_INCLUDED_#{@hid} */
      EOS
    end

    File.open(@sname, "wt") do |sio|
      sstream = ::Packcr::Stream.new(sio, @sname, @lines ? 0 : nil)
      sstream.write "/* A packrat parser generated by PackCR %s */\n\n" % ::Packcr::VERSION

      @esource.each do |code|
        sstream.write_code_block(code, 0, @iname)
      end
      sstream.write "\n" if !@esource.empty?

      sstream.write(<<~EOS)
        #ifdef _MSC_VER
        #undef _CRT_SECURE_NO_WARNINGS
        #define _CRT_SECURE_NO_WARNINGS
        #endif /* _MSC_VER */
        #include <stdio.h>
        #include <stdlib.h>
        #include <string.h>

        #ifndef _MSC_VER
        #if defined __GNUC__ && defined _WIN32 /* MinGW */
        #ifndef PCC_USE_SYSTEM_STRNLEN
        #define strnlen(str, maxlen) pcc_strnlen(str, maxlen)
        static size_t pcc_strnlen(const char *str, size_t maxlen) {
            size_t i;
            for (i = 0; i < maxlen && str[i]; i++);
            return i;
        }
        #endif /* !PCC_USE_SYSTEM_STRNLEN */
        #endif /* defined __GNUC__ && defined _WIN32 */
        #endif /* !_MSC_VER */

        #include "#{@hname}"

      EOS

      @source.each do |code|
        sstream.write_code_block(code, 0, @iname)
      end

      sstream.write(<<~EOS)
        #if !defined __has_attribute || defined _MSC_VER
        #define __attribute__(x)
        #endif

        #ifdef _MSC_VER
        #define MARK_FUNC_AS_USED __pragma(warning(suppress:4505))
        #else
        #define MARK_FUNC_AS_USED __attribute__((__unused__))
        #endif

        #ifndef PCC_BUFFER_MIN_SIZE
        #define PCC_BUFFER_MIN_SIZE 256
        #endif /* !PCC_BUFFER_MIN_SIZE */

        #ifndef PCC_ARRAY_MIN_SIZE
        #define PCC_ARRAY_MIN_SIZE 2
        #endif /* !PCC_ARRAY_MIN_SIZE */

        #ifndef PCC_POOL_MIN_SIZE
        #define PCC_POOL_MIN_SIZE 65536
        #endif /* !PCC_POOL_MIN_SIZE */

        #define PCC_DBG_EVALUATE 0
        #define PCC_DBG_MATCH    1
        #define PCC_DBG_NOMATCH  2

        #define PCC_VOID_VALUE (~(size_t)0)

        typedef enum pcc_bool_tag {
            PCC_FALSE = 0,
            PCC_TRUE
        } pcc_bool_t;

        typedef struct pcc_char_array_tag {
            char *buf;
            size_t max;
            size_t len;
        } pcc_char_array_t;

        typedef struct pcc_range_tag {
            size_t start;
            size_t end;
        } pcc_range_t;

        typedef #{value_def}pcc_value_t;

        typedef #{auxil_def}pcc_auxil_t;

      EOS

      if @prefix != "pcc"
        sstream.write(<<~EOS)
          typedef #{prefix}_context_t pcc_context_t;

        EOS
      end

      sstream.write(<<~EOS)
        typedef struct pcc_value_table_tag {
            pcc_value_t *buf;
            size_t max;
            size_t len;
        } pcc_value_table_t;

        typedef struct pcc_value_refer_table_tag {
            pcc_value_t **buf;
            size_t max;
            size_t len;
        } pcc_value_refer_table_t;

        typedef struct pcc_capture_tag {
            pcc_range_t range;
            char *string; /* mutable */
        } pcc_capture_t;

        typedef struct pcc_capture_table_tag {
            pcc_capture_t *buf;
            size_t max;
            size_t len;
        } pcc_capture_table_t;

        typedef struct pcc_capture_const_table_tag {
            const pcc_capture_t **buf;
            size_t max;
            size_t len;
        } pcc_capture_const_table_t;

        typedef struct pcc_thunk_tag pcc_thunk_t;
        typedef struct pcc_thunk_array_tag pcc_thunk_array_t;

        typedef void (*pcc_action_t)(pcc_context_t *, pcc_thunk_t *, pcc_value_t *);

      EOS
      sstream.write(<<~EOS)
        typedef enum pcc_thunk_type_tag {
            PCC_THUNK_LEAF,
            PCC_THUNK_NODE
        } pcc_thunk_type_t;

        typedef struct pcc_thunk_leaf_tag {
            pcc_value_refer_table_t values;
            pcc_capture_const_table_t capts;
            pcc_capture_t capt0;
            pcc_action_t action;
        } pcc_thunk_leaf_t;

        typedef struct pcc_thunk_node_tag {
            const pcc_thunk_array_t *thunks; /* just a reference */
            pcc_value_t *value; /* just a reference */
        } pcc_thunk_node_t;

        typedef union pcc_thunk_data_tag {
            pcc_thunk_leaf_t leaf;
            pcc_thunk_node_t node;
        } pcc_thunk_data_t;

        struct pcc_thunk_tag {
            pcc_thunk_type_t type;
            pcc_thunk_data_t data;
        };

        struct pcc_thunk_array_tag {
            pcc_thunk_t **buf;
            size_t max;
            size_t len;
        };

        typedef struct pcc_thunk_chunk_tag {
            pcc_value_table_t values;
            pcc_capture_table_t capts;
            pcc_thunk_array_t thunks;
            size_t pos; /* the starting position in the character buffer */
        } pcc_thunk_chunk_t;

        typedef struct pcc_lr_entry_tag pcc_lr_entry_t;

        typedef enum pcc_lr_answer_type_tag {
            PCC_LR_ANSWER_LR,
            PCC_LR_ANSWER_CHUNK
        } pcc_lr_answer_type_t;

        typedef union pcc_lr_answer_data_tag {
            pcc_lr_entry_t *lr;
            pcc_thunk_chunk_t *chunk;
        } pcc_lr_answer_data_t;

        typedef struct pcc_lr_answer_tag pcc_lr_answer_t;

        struct pcc_lr_answer_tag {
            pcc_lr_answer_type_t type;
            pcc_lr_answer_data_t data;
            size_t pos; /* the absolute position in the input */
            pcc_lr_answer_t *hold;
        };

      EOS
      sstream.write(<<~EOS)
        typedef pcc_thunk_chunk_t *(*pcc_rule_t)(pcc_context_t *);

        typedef struct pcc_rule_set_tag {
            pcc_rule_t *buf;
            size_t max;
            size_t len;
        } pcc_rule_set_t;

        typedef struct pcc_lr_head_tag pcc_lr_head_t;

        struct pcc_lr_head_tag {
            pcc_rule_t rule;
            pcc_rule_set_t invol;
            pcc_rule_set_t eval;
            pcc_lr_head_t *hold;
        };

        typedef struct pcc_lr_memo_tag {
            pcc_rule_t rule;
            pcc_lr_answer_t *answer;
        } pcc_lr_memo_t;

        typedef struct pcc_lr_memo_map_tag {
            pcc_lr_memo_t *buf;
            size_t max;
            size_t len;
        } pcc_lr_memo_map_t;

        typedef struct pcc_lr_table_entry_tag {
            pcc_lr_head_t *head; /* just a reference */
            pcc_lr_memo_map_t memos;
            pcc_lr_answer_t *hold_a;
            pcc_lr_head_t *hold_h;
        } pcc_lr_table_entry_t;

        typedef struct pcc_lr_table_tag {
            pcc_lr_table_entry_t **buf;
            size_t max;
            size_t len;
            size_t ofs;
        } pcc_lr_table_t;

        struct pcc_lr_entry_tag {
            pcc_rule_t rule;
            pcc_thunk_chunk_t *seed; /* just a reference */
            pcc_lr_head_t *head; /* just a reference */
        };

        typedef struct pcc_lr_stack_tag {
            pcc_lr_entry_t **buf;
            size_t max;
            size_t len;
        } pcc_lr_stack_t;

      EOS
      sstream.write(<<~EOS)
        typedef struct pcc_memory_entry_tag pcc_memory_entry_t;
        typedef struct pcc_memory_pool_tag pcc_memory_pool_t;

        struct pcc_memory_entry_tag {
            pcc_memory_entry_t *next;
        };

        struct pcc_memory_pool_tag {
            pcc_memory_pool_t *next;
            size_t allocated;
            size_t unused;
        };

        typedef struct pcc_memory_recycler_tag {
            pcc_memory_pool_t *pool_list;
            pcc_memory_entry_t *entry_list;
            size_t element_size;
        } pcc_memory_recycler_t;

        struct #{prefix}_context_tag {
            size_t pos; /* the position in the input of the first character currently buffered */
            size_t cur; /* the current parsing position in the character buffer */
            size_t level;
            pcc_char_array_t buffer;
            pcc_lr_table_t lrtable;
            pcc_lr_stack_t lrstack;
            pcc_thunk_array_t thunks;
            pcc_auxil_t auxil;
            pcc_memory_recycler_t thunk_chunk_recycler;
            pcc_memory_recycler_t lr_head_recycler;
            pcc_memory_recycler_t lr_answer_recycler;
        };

      EOS
      sstream.write(<<~EOS)
        #ifndef PCC_ERROR
        #define PCC_ERROR(auxil) pcc_error()
        MARK_FUNC_AS_USED
        static void pcc_error(void) {
            fprintf(stderr, \"Syntax error\\n\");
            exit(1);
        }
        #endif /* !PCC_ERROR */

        #ifndef PCC_GETCHAR
        #define PCC_GETCHAR(auxil) getchar()
        #endif /* !PCC_GETCHAR */

        #ifndef PCC_MALLOC
        #define PCC_MALLOC(auxil, size) pcc_malloc_e(size)
        static void *pcc_malloc_e(size_t size) {
            void *const p = malloc(size);
            if (p == NULL) {
                fprintf(stderr, \"Out of memory\\n\");
                exit(1);
            }
            return p;
        }
        #endif /* !PCC_MALLOC */

        #ifndef PCC_REALLOC
        #define PCC_REALLOC(auxil, ptr, size) pcc_realloc_e(ptr, size)
        static void *pcc_realloc_e(void *ptr, size_t size) {
            void *const p = realloc(ptr, size);
            if (p == NULL) {
                fprintf(stderr, \"Out of memory\\n\");
                exit(1);
            }
            return p;
        }
        #endif /* !PCC_REALLOC */

        #ifndef PCC_FREE
        #define PCC_FREE(auxil, ptr) free(ptr)
        #endif /* !PCC_FREE */

        #ifndef PCC_DEBUG
        #define PCC_DEBUG(auxil, event, rule, level, pos, buffer, length) ((void)0)
        #endif /* !PCC_DEBUG */

        static char *pcc_strndup_e(pcc_auxil_t auxil, const char *str, size_t len) {
            const size_t m = strnlen(str, len);
            char *const s = (char *)PCC_MALLOC(auxil, m + 1);
            memcpy(s, str, m);
            s[m] = '\\0';
            return s;
        }

      EOS
      sstream.write(<<~EOS)
        static void pcc_char_array__init(pcc_auxil_t auxil, pcc_char_array_t *array) {
            array->len = 0;
            array->max = 0;
            array->buf = NULL;
        }

        static void pcc_char_array__add(pcc_auxil_t auxil, pcc_char_array_t *array, char ch) {
            if (array->max <= array->len) {
                const size_t n = array->len + 1;
                size_t m = array->max;
                if (m == 0) m = PCC_BUFFER_MIN_SIZE;
                while (m < n && m != 0) m <<= 1;
                if (m == 0) m = n;
                array->buf = (char *)PCC_REALLOC(auxil, array->buf, m);
                array->max = m;
            }
            array->buf[array->len++] = ch;
        }

        static void pcc_char_array__term(pcc_auxil_t auxil, pcc_char_array_t *array) {
            PCC_FREE(auxil, array->buf);
        }

      EOS
      sstream.write(<<~EOS)
        static void pcc_value_table__init(pcc_auxil_t auxil, pcc_value_table_t *table) {
            table->len = 0;
            table->max = 0;
            table->buf = NULL;
        }

        MARK_FUNC_AS_USED
        static void pcc_value_table__resize(pcc_auxil_t auxil, pcc_value_table_t *table, size_t len) {
            if (table->max < len) {
                size_t m = table->max;
                if (m == 0) m = PCC_ARRAY_MIN_SIZE;
                while (m < len && m != 0) m <<= 1;
                if (m == 0) m = len;
                table->buf = (pcc_value_t *)PCC_REALLOC(auxil, table->buf, sizeof(pcc_value_t) * m);
                table->max = m;
            }
            table->len = len;
        }

        MARK_FUNC_AS_USED
        static void pcc_value_table__clear(pcc_auxil_t auxil, pcc_value_table_t *table) {
            memset(table->buf, 0, sizeof(pcc_value_t) * table->len);
        }

        static void pcc_value_table__term(pcc_auxil_t auxil, pcc_value_table_t *table) {
            PCC_FREE(auxil, table->buf);
        }

      EOS
      sstream.write(<<~EOS)
        static void pcc_value_refer_table__init(pcc_auxil_t auxil, pcc_value_refer_table_t *table) {
            table->len = 0;
            table->max = 0;
            table->buf = NULL;
        }

        static void pcc_value_refer_table__resize(pcc_auxil_t auxil, pcc_value_refer_table_t *table, size_t len) {
            size_t i;
            if (table->max < len) {
                size_t m = table->max;
                if (m == 0) m = PCC_ARRAY_MIN_SIZE;
                while (m < len && m != 0) m <<= 1;
                if (m == 0) m = len;
                table->buf = (pcc_value_t **)PCC_REALLOC(auxil, table->buf, sizeof(pcc_value_t *) * m);
                table->max = m;
            }
            for (i = table->len; i < len; i++) table->buf[i] = NULL;
            table->len = len;
        }

        static void pcc_value_refer_table__term(pcc_auxil_t auxil, pcc_value_refer_table_t *table) {
            PCC_FREE(auxil, table->buf);
        }

      EOS
      sstream.write(<<~EOS)
        static void pcc_capture_table__init(pcc_auxil_t auxil, pcc_capture_table_t *table) {
            table->len = 0;
            table->max = 0;
            table->buf = NULL;
        }

        MARK_FUNC_AS_USED
        static void pcc_capture_table__resize(pcc_auxil_t auxil, pcc_capture_table_t *table, size_t len) {
            size_t i;
            for (i = len; i < table->len; i++) PCC_FREE(auxil, table->buf[i].string);
            if (table->max < len) {
                size_t m = table->max;
                if (m == 0) m = PCC_ARRAY_MIN_SIZE;
                while (m < len && m != 0) m <<= 1;
                if (m == 0) m = len;
                table->buf = (pcc_capture_t *)PCC_REALLOC(auxil, table->buf, sizeof(pcc_capture_t) * m);
                table->max = m;
            }
            for (i = table->len; i < len; i++) {
                table->buf[i].range.start = 0;
                table->buf[i].range.end = 0;
                table->buf[i].string = NULL;
            }
            table->len = len;
        }

        static void pcc_capture_table__term(pcc_auxil_t auxil, pcc_capture_table_t *table) {
            while (table->len > 0) {
                table->len--;
                PCC_FREE(auxil, table->buf[table->len].string);
            }
            PCC_FREE(auxil, table->buf);
        }

      EOS
      sstream.write(<<~EOS)
        static void pcc_capture_const_table__init(pcc_auxil_t auxil, pcc_capture_const_table_t *table) {
            table->len = 0;
            table->max = 0;
            table->buf = NULL;
        }

        static void pcc_capture_const_table__resize(pcc_auxil_t auxil, pcc_capture_const_table_t *table, size_t len) {
            size_t i;
            if (table->max < len) {
                size_t m = table->max;
                if (m == 0) m = PCC_ARRAY_MIN_SIZE;
                while (m < len && m != 0) m <<= 1;
                if (m == 0) m = len;
                table->buf = (const pcc_capture_t **)PCC_REALLOC(auxil, (pcc_capture_t **)table->buf, sizeof(const pcc_capture_t *) * m);
                table->max = m;
            }
            for (i = table->len; i < len; i++) table->buf[i] = NULL;
            table->len = len;
        }

        static void pcc_capture_const_table__term(pcc_auxil_t auxil, pcc_capture_const_table_t *table) {
            PCC_FREE(auxil, (void *)table->buf);
        }

      EOS
      sstream.write(<<~EOS)
        MARK_FUNC_AS_USED
        static pcc_thunk_t *pcc_thunk__create_leaf(pcc_auxil_t auxil, pcc_action_t action, size_t valuec, size_t captc) {
            pcc_thunk_t *const thunk = (pcc_thunk_t *)PCC_MALLOC(auxil, sizeof(pcc_thunk_t));
            thunk->type = PCC_THUNK_LEAF;
            pcc_value_refer_table__init(auxil, &thunk->data.leaf.values);
            pcc_value_refer_table__resize(auxil, &thunk->data.leaf.values, valuec);
            pcc_capture_const_table__init(auxil, &thunk->data.leaf.capts);
            pcc_capture_const_table__resize(auxil, &thunk->data.leaf.capts, captc);
            thunk->data.leaf.capt0.range.start = 0;
            thunk->data.leaf.capt0.range.end = 0;
            thunk->data.leaf.capt0.string = NULL;
            thunk->data.leaf.action = action;
            return thunk;
        }

        static pcc_thunk_t *pcc_thunk__create_node(pcc_auxil_t auxil, const pcc_thunk_array_t *thunks, pcc_value_t *value) {
            pcc_thunk_t *const thunk = (pcc_thunk_t *)PCC_MALLOC(auxil, sizeof(pcc_thunk_t));
            thunk->type = PCC_THUNK_NODE;
            thunk->data.node.thunks = thunks;
            thunk->data.node.value = value;
            return thunk;
        }

        static void pcc_thunk__destroy(pcc_auxil_t auxil, pcc_thunk_t *thunk) {
            if (thunk == NULL) return;
            switch (thunk->type) {
            case PCC_THUNK_LEAF:
                PCC_FREE(auxil, thunk->data.leaf.capt0.string);
                pcc_capture_const_table__term(auxil, &thunk->data.leaf.capts);
                pcc_value_refer_table__term(auxil, &thunk->data.leaf.values);
                break;
            case PCC_THUNK_NODE:
                break;
            default: /* unknown */
                break;
            }
            PCC_FREE(auxil, thunk);
        }

      EOS
      sstream.write(<<~EOS)
        static void pcc_thunk_array__init(pcc_auxil_t auxil, pcc_thunk_array_t *array) {
            array->len = 0;
            array->max = 0;
            array->buf = NULL;
        }

        static void pcc_thunk_array__add(pcc_auxil_t auxil, pcc_thunk_array_t *array, pcc_thunk_t *thunk) {
            if (array->max <= array->len) {
                const size_t n = array->len + 1;
                size_t m = array->max;
                if (m == 0) m = PCC_ARRAY_MIN_SIZE;
                while (m < n && m != 0) m <<= 1;
                if (m == 0) m = n;
                array->buf = (pcc_thunk_t **)PCC_REALLOC(auxil, array->buf, sizeof(pcc_thunk_t *) * m);
                array->max = m;
            }
            array->buf[array->len++] = thunk;
        }

        static void pcc_thunk_array__revert(pcc_auxil_t auxil, pcc_thunk_array_t *array, size_t len) {
            while (array->len > len) {
                array->len--;
                pcc_thunk__destroy(auxil, array->buf[array->len]);
            }
        }

        static void pcc_thunk_array__term(pcc_auxil_t auxil, pcc_thunk_array_t *array) {
            while (array->len > 0) {
                array->len--;
                pcc_thunk__destroy(auxil, array->buf[array->len]);
            }
            PCC_FREE(auxil, array->buf);
        }

      EOS
      sstream.write(<<~EOS)
        static void pcc_memory_recycler__init(pcc_auxil_t auxil, pcc_memory_recycler_t *recycler, size_t element_size) {
            recycler->pool_list = NULL;
            recycler->entry_list = NULL;
            recycler->element_size = element_size;
        }

        static void *pcc_memory_recycler__supply(pcc_auxil_t auxil, pcc_memory_recycler_t *recycler) {
            if (recycler->entry_list) {
                pcc_memory_entry_t *const tmp = recycler->entry_list;
                recycler->entry_list = tmp->next;
                return tmp;
            }
            if (!recycler->pool_list || recycler->pool_list->unused == 0) {
                size_t size = PCC_POOL_MIN_SIZE;
                if (recycler->pool_list) {
                    size = recycler->pool_list->allocated << 1;
                    if (size == 0) size = recycler->pool_list->allocated;
                }
                {
                    pcc_memory_pool_t *const pool = (pcc_memory_pool_t *)PCC_MALLOC(
                        auxil, sizeof(pcc_memory_pool_t) + recycler->element_size * size
                    );
                    pool->allocated = size;
                    pool->unused = size;
                    pool->next = recycler->pool_list;
                    recycler->pool_list = pool;
                }
            }
            recycler->pool_list->unused--;
            return (char *)recycler->pool_list + sizeof(pcc_memory_pool_t) + recycler->element_size * recycler->pool_list->unused;
        }

        static void pcc_memory_recycler__recycle(pcc_auxil_t auxil, pcc_memory_recycler_t *recycler, void *ptr) {
            pcc_memory_entry_t *const tmp = (pcc_memory_entry_t *)ptr;
            tmp->next = recycler->entry_list;
            recycler->entry_list = tmp;
        }

        static void pcc_memory_recycler__term(pcc_auxil_t auxil, pcc_memory_recycler_t *recycler) {
            while (recycler->pool_list) {
                pcc_memory_pool_t *const tmp = recycler->pool_list;
                recycler->pool_list = tmp->next;
                PCC_FREE(auxil, tmp);
            }
        }

      EOS
      sstream.write(<<~EOS)
        MARK_FUNC_AS_USED
        static pcc_thunk_chunk_t *pcc_thunk_chunk__create(pcc_context_t *ctx) {
            pcc_thunk_chunk_t *const chunk = (pcc_thunk_chunk_t *)pcc_memory_recycler__supply(ctx->auxil, &ctx->thunk_chunk_recycler);
            pcc_value_table__init(ctx->auxil, &chunk->values);
            pcc_capture_table__init(ctx->auxil, &chunk->capts);
            pcc_thunk_array__init(ctx->auxil, &chunk->thunks);
            chunk->pos = 0;
            return chunk;
        }

        static void pcc_thunk_chunk__destroy(pcc_context_t *ctx, pcc_thunk_chunk_t *chunk) {
            if (chunk == NULL) return;
            pcc_thunk_array__term(ctx->auxil, &chunk->thunks);
            pcc_capture_table__term(ctx->auxil, &chunk->capts);
            pcc_value_table__term(ctx->auxil, &chunk->values);
            pcc_memory_recycler__recycle(ctx->auxil, &ctx->thunk_chunk_recycler, chunk);
        }

      EOS
      sstream.write(<<~EOS)
        static void pcc_rule_set__init(pcc_auxil_t auxil, pcc_rule_set_t *set) {
            set->len = 0;
            set->max = 0;
            set->buf = NULL;
        }

        static size_t pcc_rule_set__index(pcc_auxil_t auxil, const pcc_rule_set_t *set, pcc_rule_t rule) {
            size_t i;
            for (i = 0; i < set->len; i++) {
                if (set->buf[i] == rule) return i;
            }
            return PCC_VOID_VALUE;
        }

        static pcc_bool_t pcc_rule_set__add(pcc_auxil_t auxil, pcc_rule_set_t *set, pcc_rule_t rule) {
            const size_t i = pcc_rule_set__index(auxil, set, rule);
            if (i != PCC_VOID_VALUE) return PCC_FALSE;
            if (set->max <= set->len) {
                const size_t n = set->len + 1;
                size_t m = set->max;
                if (m == 0) m = PCC_ARRAY_MIN_SIZE;
                while (m < n && m != 0) m <<= 1;
                if (m == 0) m = n;
                set->buf = (pcc_rule_t *)PCC_REALLOC(auxil, set->buf, sizeof(pcc_rule_t) * m);
                set->max = m;
            }
            set->buf[set->len++] = rule;
            return PCC_TRUE;
        }

        static pcc_bool_t pcc_rule_set__remove(pcc_auxil_t auxil, pcc_rule_set_t *set, pcc_rule_t rule) {
            const size_t i = pcc_rule_set__index(auxil, set, rule);
            if (i == PCC_VOID_VALUE) return PCC_FALSE;
            memmove(set->buf + i, set->buf + (i + 1), sizeof(pcc_rule_t) * (set->len - (i + 1)));
            return PCC_TRUE;
        }

        static void pcc_rule_set__clear(pcc_auxil_t auxil, pcc_rule_set_t *set) {
            set->len = 0;
        }

        static void pcc_rule_set__copy(pcc_auxil_t auxil, pcc_rule_set_t *set, const pcc_rule_set_t *src) {
            size_t i;
            pcc_rule_set__clear(auxil, set);
            for (i = 0; i < src->len; i++) {
                pcc_rule_set__add(auxil, set, src->buf[i]);
            }
        }

        static void pcc_rule_set__term(pcc_auxil_t auxil, pcc_rule_set_t *set) {
            PCC_FREE(auxil, set->buf);
        }

      EOS
      sstream.write(<<~EOS)
        static pcc_lr_head_t *pcc_lr_head__create(pcc_context_t *ctx, pcc_rule_t rule) {
            pcc_lr_head_t *const head = (pcc_lr_head_t *)pcc_memory_recycler__supply(ctx->auxil, &ctx->lr_head_recycler);
            head->rule = rule;
            pcc_rule_set__init(ctx->auxil, &head->invol);
            pcc_rule_set__init(ctx->auxil, &head->eval);
            head->hold = NULL;
            return head;
        }

        static void pcc_lr_head__destroy(pcc_context_t *ctx, pcc_lr_head_t *head) {
            if (head == NULL) return;
            pcc_lr_head__destroy(ctx, head->hold);
            pcc_rule_set__term(ctx->auxil, &head->eval);
            pcc_rule_set__term(ctx->auxil, &head->invol);
            pcc_memory_recycler__recycle(ctx->auxil, &ctx->lr_head_recycler, head);
        }

      EOS
      sstream.write(<<~EOS)
        static void pcc_lr_entry__destroy(pcc_auxil_t auxil, pcc_lr_entry_t *lr);

        static pcc_lr_answer_t *pcc_lr_answer__create(pcc_context_t *ctx, pcc_lr_answer_type_t type, size_t pos) {
            pcc_lr_answer_t *answer = (pcc_lr_answer_t *)pcc_memory_recycler__supply(ctx->auxil, &ctx->lr_answer_recycler);
            answer->type = type;
            answer->pos = pos;
            answer->hold = NULL;
            switch (answer->type) {
            case PCC_LR_ANSWER_LR:
                answer->data.lr = NULL;
                break;
            case PCC_LR_ANSWER_CHUNK:
                answer->data.chunk = NULL;
                break;
            default: /* unknown */
                PCC_FREE(ctx->auxil, answer);
                answer = NULL;
            }
            return answer;
        }

        static void pcc_lr_answer__set_chunk(pcc_context_t *ctx, pcc_lr_answer_t *answer, pcc_thunk_chunk_t *chunk) {
            pcc_lr_answer_t *const a = pcc_lr_answer__create(ctx, answer->type, answer->pos);
            switch (answer->type) {
            case PCC_LR_ANSWER_LR:
                a->data.lr = answer->data.lr;
                break;
            case PCC_LR_ANSWER_CHUNK:
                a->data.chunk = answer->data.chunk;
                break;
            default: /* unknown */
                break;
            }
            a->hold = answer->hold;
            answer->hold = a;
            answer->type = PCC_LR_ANSWER_CHUNK;
            answer->data.chunk = chunk;
        }

        static void pcc_lr_answer__destroy(pcc_context_t *ctx, pcc_lr_answer_t *answer) {
            while (answer != NULL) {
                pcc_lr_answer_t *const a = answer->hold;
                switch (answer->type) {
                case PCC_LR_ANSWER_LR:
                    pcc_lr_entry__destroy(ctx->auxil, answer->data.lr);
                    break;
                case PCC_LR_ANSWER_CHUNK:
                    pcc_thunk_chunk__destroy(ctx, answer->data.chunk);
                    break;
                default: /* unknown */
                    break;
                }
                pcc_memory_recycler__recycle(ctx->auxil, &ctx->lr_answer_recycler, answer);
                answer = a;
            }
        }

      EOS
      sstream.write(<<~EOS)
        static void pcc_lr_memo_map__init(pcc_auxil_t auxil, pcc_lr_memo_map_t *map) {
            map->len = 0;
            map->max = 0;
            map->buf = NULL;
        }

        static size_t pcc_lr_memo_map__index(pcc_context_t *ctx, pcc_lr_memo_map_t *map, pcc_rule_t rule) {
            size_t i;
            for (i = 0; i < map->len; i++) {
                if (map->buf[i].rule == rule) return i;
            }
            return PCC_VOID_VALUE;
        }

        static void pcc_lr_memo_map__put(pcc_context_t *ctx, pcc_lr_memo_map_t *map, pcc_rule_t rule, pcc_lr_answer_t *answer) {
            const size_t i = pcc_lr_memo_map__index(ctx, map, rule);
            if (i != PCC_VOID_VALUE) {
                pcc_lr_answer__destroy(ctx, map->buf[i].answer);
                map->buf[i].answer = answer;
            }
            else {
                if (map->max <= map->len) {
                    const size_t n = map->len + 1;
                    size_t m = map->max;
                    if (m == 0) m = PCC_ARRAY_MIN_SIZE;
                    while (m < n && m != 0) m <<= 1;
                    if (m == 0) m = n;
                    map->buf = (pcc_lr_memo_t *)PCC_REALLOC(ctx->auxil, map->buf, sizeof(pcc_lr_memo_t) * m);
                    map->max = m;
                }
                map->buf[map->len].rule = rule;
                map->buf[map->len].answer = answer;
                map->len++;
            }
        }

        static pcc_lr_answer_t *pcc_lr_memo_map__get(pcc_context_t *ctx, pcc_lr_memo_map_t *map, pcc_rule_t rule) {
            const size_t i = pcc_lr_memo_map__index(ctx, map, rule);
            return (i != PCC_VOID_VALUE) ? map->buf[i].answer : NULL;
        }

        static void pcc_lr_memo_map__term(pcc_context_t *ctx, pcc_lr_memo_map_t *map) {
            while (map->len > 0) {
                map->len--;
                pcc_lr_answer__destroy(ctx, map->buf[map->len].answer);
            }
            PCC_FREE(ctx->auxil, map->buf);
        }

      EOS
      sstream.write(<<~EOS)
        static pcc_lr_table_entry_t *pcc_lr_table_entry__create(pcc_context_t *ctx) {
            pcc_lr_table_entry_t *const entry = (pcc_lr_table_entry_t *)PCC_MALLOC(ctx->auxil, sizeof(pcc_lr_table_entry_t));
            entry->head = NULL;
            pcc_lr_memo_map__init(ctx->auxil, &entry->memos);
            entry->hold_a = NULL;
            entry->hold_h = NULL;
            return entry;
        }

        static void pcc_lr_table_entry__destroy(pcc_context_t *ctx, pcc_lr_table_entry_t *entry) {
            if (entry == NULL) return;
            pcc_lr_head__destroy(ctx, entry->hold_h);
            pcc_lr_answer__destroy(ctx, entry->hold_a);
            pcc_lr_memo_map__term(ctx, &entry->memos);
            PCC_FREE(ctx->auxil, entry);
        }

      EOS
      sstream.write(<<~EOS)
        static void pcc_lr_table__init(pcc_auxil_t auxil, pcc_lr_table_t *table) {
            table->ofs = 0;
            table->len = 0;
            table->max = 0;
            table->buf = NULL;
        }

        static void pcc_lr_table__resize(pcc_context_t *ctx, pcc_lr_table_t *table, size_t len) {
            size_t i;
            for (i = len; i < table->len; i++) pcc_lr_table_entry__destroy(ctx, table->buf[i]);
            if (table->max < len) {
                size_t m = table->max;
                if (m == 0) m = PCC_ARRAY_MIN_SIZE;
                while (m < len && m != 0) m <<= 1;
                if (m == 0) m = len;
                table->buf = (pcc_lr_table_entry_t **)PCC_REALLOC(ctx->auxil, table->buf, sizeof(pcc_lr_table_entry_t *) * m);
                table->max = m;
            }
            for (i = table->len; i < len; i++) table->buf[i] = NULL;
            table->len = len;
        }

        static void pcc_lr_table__set_head(pcc_context_t *ctx, pcc_lr_table_t *table, size_t index, pcc_lr_head_t *head) {
            index += table->ofs;
            if (index >= table->len) pcc_lr_table__resize(ctx, table, index + 1);
            if (table->buf[index] == NULL) table->buf[index] = pcc_lr_table_entry__create(ctx);
            table->buf[index]->head = head;
        }

        static void pcc_lr_table__hold_head(pcc_context_t *ctx, pcc_lr_table_t *table, size_t index, pcc_lr_head_t *head) {
            index += table->ofs;
            if (index >= table->len) pcc_lr_table__resize(ctx, table, index + 1);
            if (table->buf[index] == NULL) table->buf[index] = pcc_lr_table_entry__create(ctx);
            head->hold = table->buf[index]->hold_h;
            table->buf[index]->hold_h = head;
        }

        static void pcc_lr_table__set_answer(pcc_context_t *ctx, pcc_lr_table_t *table, size_t index, pcc_rule_t rule, pcc_lr_answer_t *answer) {
            index += table->ofs;
            if (index >= table->len) pcc_lr_table__resize(ctx, table, index + 1);
            if (table->buf[index] == NULL) table->buf[index] = pcc_lr_table_entry__create(ctx);
            pcc_lr_memo_map__put(ctx, &table->buf[index]->memos, rule, answer);
        }

        static void pcc_lr_table__hold_answer(pcc_context_t *ctx, pcc_lr_table_t *table, size_t index, pcc_lr_answer_t *answer) {
            index += table->ofs;
            if (index >= table->len) pcc_lr_table__resize(ctx, table, index + 1);
            if (table->buf[index] == NULL) table->buf[index] = pcc_lr_table_entry__create(ctx);
            answer->hold = table->buf[index]->hold_a;
            table->buf[index]->hold_a = answer;
        }

        static pcc_lr_head_t *pcc_lr_table__get_head(pcc_context_t *ctx, pcc_lr_table_t *table, size_t index) {
            index += table->ofs;
            if (index >= table->len || table->buf[index] == NULL) return NULL;
            return table->buf[index]->head;
        }

        static pcc_lr_answer_t *pcc_lr_table__get_answer(pcc_context_t *ctx, pcc_lr_table_t *table, size_t index, pcc_rule_t rule) {
            index += table->ofs;
            if (index >= table->len || table->buf[index] == NULL) return NULL;
            return pcc_lr_memo_map__get(ctx, &table->buf[index]->memos, rule);
        }

        static void pcc_lr_table__shift(pcc_context_t *ctx, pcc_lr_table_t *table, size_t count) {
            size_t i;
            if (count > table->len - table->ofs) count = table->len - table->ofs;
            for (i = 0; i < count; i++) pcc_lr_table_entry__destroy(ctx, table->buf[table->ofs++]);
            if (table->ofs > (table->max >> 1)) {
                memmove(table->buf, table->buf + table->ofs, sizeof(pcc_lr_table_entry_t *) * (table->len - table->ofs));
                table->len -= table->ofs;
                table->ofs = 0;
            }
        }

        static void pcc_lr_table__term(pcc_context_t *ctx, pcc_lr_table_t *table) {
            while (table->len > table->ofs) {
                table->len--;
                pcc_lr_table_entry__destroy(ctx, table->buf[table->len]);
            }
            PCC_FREE(ctx->auxil, table->buf);
        }

      EOS
      sstream.write(<<~EOS)
        static pcc_lr_entry_t *pcc_lr_entry__create(pcc_auxil_t auxil, pcc_rule_t rule) {
            pcc_lr_entry_t *const lr = (pcc_lr_entry_t *)PCC_MALLOC(auxil, sizeof(pcc_lr_entry_t));
            lr->rule = rule;
            lr->seed = NULL;
            lr->head = NULL;
            return lr;
        }

        static void pcc_lr_entry__destroy(pcc_auxil_t auxil, pcc_lr_entry_t *lr) {
            PCC_FREE(auxil, lr);
        }

      EOS
      sstream.write(<<~EOS)
        static void pcc_lr_stack__init(pcc_auxil_t auxil, pcc_lr_stack_t *stack) {
            stack->len = 0;
            stack->max = 0;
            stack->buf = NULL;
        }

        static void pcc_lr_stack__push(pcc_auxil_t auxil, pcc_lr_stack_t *stack, pcc_lr_entry_t *lr) {
            if (stack->max <= stack->len) {
                const size_t n = stack->len + 1;
                size_t m = stack->max;
                if (m == 0) m = PCC_ARRAY_MIN_SIZE;
                while (m < n && m != 0) m <<= 1;
                if (m == 0) m = n;
                stack->buf = (pcc_lr_entry_t **)PCC_REALLOC(auxil, stack->buf, sizeof(pcc_lr_entry_t *) * m);
                stack->max = m;
            }
            stack->buf[stack->len++] = lr;
        }

        static pcc_lr_entry_t *pcc_lr_stack__pop(pcc_auxil_t auxil, pcc_lr_stack_t *stack) {
            return stack->buf[--stack->len];
        }

        static void pcc_lr_stack__term(pcc_auxil_t auxil, pcc_lr_stack_t *stack) {
            PCC_FREE(auxil, stack->buf);
        }

      EOS
      sstream.write(<<~EOS)
        static pcc_context_t *pcc_context__create(pcc_auxil_t auxil) {
            pcc_context_t *const ctx = (pcc_context_t *)PCC_MALLOC(auxil, sizeof(pcc_context_t));
            ctx->pos = 0;
            ctx->cur = 0;
            ctx->level = 0;
            pcc_char_array__init(auxil, &ctx->buffer);
            pcc_lr_table__init(auxil, &ctx->lrtable);
            pcc_lr_stack__init(auxil, &ctx->lrstack);
            pcc_thunk_array__init(auxil, &ctx->thunks);
            pcc_memory_recycler__init(auxil, &ctx->thunk_chunk_recycler, sizeof(pcc_thunk_chunk_t));
            pcc_memory_recycler__init(auxil, &ctx->lr_head_recycler, sizeof(pcc_lr_head_t));
            pcc_memory_recycler__init(auxil, &ctx->lr_answer_recycler, sizeof(pcc_lr_answer_t));
            ctx->auxil = auxil;
            return ctx;
        }

      EOS
      sstream.write(<<~EOS)
        static void pcc_context__destroy(pcc_context_t *ctx) {
            if (ctx == NULL) return;
            pcc_thunk_array__term(ctx->auxil, &ctx->thunks);
            pcc_lr_stack__term(ctx->auxil, &ctx->lrstack);
            pcc_lr_table__term(ctx, &ctx->lrtable);
            pcc_char_array__term(ctx->auxil, &ctx->buffer);
            pcc_memory_recycler__term(ctx->auxil, &ctx->thunk_chunk_recycler);
            pcc_memory_recycler__term(ctx->auxil, &ctx->lr_head_recycler);
            pcc_memory_recycler__term(ctx->auxil, &ctx->lr_answer_recycler);
            PCC_FREE(ctx->auxil, ctx);
        }

      EOS
      sstream.write(<<~EOS)
        static size_t pcc_refill_buffer(pcc_context_t *ctx, size_t num) {
            if (ctx->buffer.len >= ctx->cur + num) return ctx->buffer.len - ctx->cur;
            while (ctx->buffer.len < ctx->cur + num) {
                const int c = PCC_GETCHAR(ctx->auxil);
                if (c < 0) break;
                pcc_char_array__add(ctx->auxil, &ctx->buffer, (char)c);
            }
            return ctx->buffer.len - ctx->cur;
        }

      EOS
      sstream.write(<<~EOS)
        MARK_FUNC_AS_USED
        static void pcc_commit_buffer(pcc_context_t *ctx) {
            memmove(ctx->buffer.buf, ctx->buffer.buf + ctx->cur, ctx->buffer.len - ctx->cur);
            ctx->buffer.len -= ctx->cur;
            ctx->pos += ctx->cur;
            pcc_lr_table__shift(ctx, &ctx->lrtable, ctx->cur);
            ctx->cur = 0;
        }

      EOS
      sstream.write(<<~EOS)
        MARK_FUNC_AS_USED
        static const char *pcc_get_capture_string(pcc_context_t *ctx, const pcc_capture_t *capt) {
            if (capt->string == NULL)
                ((pcc_capture_t *)capt)->string =
                    pcc_strndup_e(ctx->auxil, ctx->buffer.buf + capt->range.start, capt->range.end - capt->range.start);
            return capt->string;
        }

      EOS

      if @utf8
        sstream.write(<<~EOS)
          static size_t pcc_get_char_as_utf32(pcc_context_t *ctx, int *out) { /* with checking UTF-8 validity */
              int c, u;
              size_t n;
              if (pcc_refill_buffer(ctx, 1) < 1) return 0;
              c = (int)(unsigned char)ctx->buffer.buf[ctx->cur];
              n = (c < 0x80) ? 1 :
                  ((c & 0xe0) == 0xc0) ? 2 :
                  ((c & 0xf0) == 0xe0) ? 3 :
                  ((c & 0xf8) == 0xf0) ? 4 : 0;
              if (n < 1) return 0;
              if (pcc_refill_buffer(ctx, n) < n) return 0;
              switch (n) {
              case 1:
                  u = c;
                  break;
              case 2:
                  u = c & 0x1f;
                  c = (int)(unsigned char)ctx->buffer.buf[ctx->cur + 1];
                  if ((c & 0xc0) != 0x80) return 0;
                  u <<= 6; u |= c & 0x3f;
                  if (u < 0x80) return 0;
                  break;
              case 3:
                  u = c & 0x0f;
                  c = (int)(unsigned char)ctx->buffer.buf[ctx->cur + 1];
                  if ((c & 0xc0) != 0x80) return 0;
                  u <<= 6; u |= c & 0x3f;
                  c = (int)(unsigned char)ctx->buffer.buf[ctx->cur + 2];
                  if ((c & 0xc0) != 0x80) return 0;
                  u <<= 6; u |= c & 0x3f;
                  if (u < 0x800) return 0;
                  break;
              case 4:
                  u = c & 0x07;
                  c = (int)(unsigned char)ctx->buffer.buf[ctx->cur + 1];
                  if ((c & 0xc0) != 0x80) return 0;
                  u <<= 6; u |= c & 0x3f;
                  c = (int)(unsigned char)ctx->buffer.buf[ctx->cur + 2];
                  if ((c & 0xc0) != 0x80) return 0;
                  u <<= 6; u |= c & 0x3f;
                  c = (int)(unsigned char)ctx->buffer.buf[ctx->cur + 3];
                  if ((c & 0xc0) != 0x80) return 0;
                  u <<= 6; u |= c & 0x3f;
                  if (u < 0x10000 || u > 0x10ffff) return 0;
                  break;
              default:
                  return 0;
              }
              if (out) *out = u;
              return n;
          }

        EOS
      end

      sstream.write(<<~EOS)
        MARK_FUNC_AS_USED
        static pcc_bool_t pcc_apply_rule(pcc_context_t *ctx, pcc_rule_t rule, pcc_thunk_array_t *thunks, pcc_value_t *value) {
            static pcc_value_t null;
            pcc_thunk_chunk_t *c = NULL;
            const size_t p = ctx->pos + ctx->cur;
            pcc_bool_t b = PCC_TRUE;
            pcc_lr_answer_t *a = pcc_lr_table__get_answer(ctx, &ctx->lrtable, p, rule);
            pcc_lr_head_t *h = pcc_lr_table__get_head(ctx, &ctx->lrtable, p);
            if (h != NULL) {
                if (a == NULL && rule != h->rule && pcc_rule_set__index(ctx->auxil, &h->invol, rule) == PCC_VOID_VALUE) {
                    b = PCC_FALSE;
                    c = NULL;
                }
                else if (pcc_rule_set__remove(ctx->auxil, &h->eval, rule)) {
                    b = PCC_FALSE;
                    c = rule(ctx);
                    a = pcc_lr_answer__create(ctx, PCC_LR_ANSWER_CHUNK, ctx->pos + ctx->cur);
                    a->data.chunk = c;
                    pcc_lr_table__hold_answer(ctx, &ctx->lrtable, p, a);
                }
            }
            if (b) {
                if (a != NULL) {
                    ctx->cur = a->pos - ctx->pos;
                    switch (a->type) {
                    case PCC_LR_ANSWER_LR:
                        if (a->data.lr->head == NULL) {
                            a->data.lr->head = pcc_lr_head__create(ctx, rule);
                            pcc_lr_table__hold_head(ctx, &ctx->lrtable, p, a->data.lr->head);
                        }
                        {
                            size_t i = ctx->lrstack.len;
                            while (i > 0) {
                                i--;
                                if (ctx->lrstack.buf[i]->head == a->data.lr->head) break;
                                ctx->lrstack.buf[i]->head = a->data.lr->head;
                                pcc_rule_set__add(ctx->auxil, &a->data.lr->head->invol, ctx->lrstack.buf[i]->rule);
                            }
                        }
                        c = a->data.lr->seed;
                        break;
                    case PCC_LR_ANSWER_CHUNK:
                        c = a->data.chunk;
                        break;
                    default: /* unknown */
                        break;
                    }
                }
                else {
                    pcc_lr_entry_t *const e = pcc_lr_entry__create(ctx->auxil, rule);
                    pcc_lr_stack__push(ctx->auxil, &ctx->lrstack, e);
                    a = pcc_lr_answer__create(ctx, PCC_LR_ANSWER_LR, p);
                    a->data.lr = e;
                    pcc_lr_table__set_answer(ctx, &ctx->lrtable, p, rule, a);
                    c = rule(ctx);
                    pcc_lr_stack__pop(ctx->auxil, &ctx->lrstack);
                    a->pos = ctx->pos + ctx->cur;
                    if (e->head == NULL) {
                        pcc_lr_answer__set_chunk(ctx, a, c);
                    }
                    else {
                        e->seed = c;
                        h = a->data.lr->head;
                        if (h->rule != rule) {
                            c = a->data.lr->seed;
                            a = pcc_lr_answer__create(ctx, PCC_LR_ANSWER_CHUNK, ctx->pos + ctx->cur);
                            a->data.chunk = c;
                            pcc_lr_table__hold_answer(ctx, &ctx->lrtable, p, a);
                        }
                        else {
                            pcc_lr_answer__set_chunk(ctx, a, a->data.lr->seed);
                            if (a->data.chunk == NULL) {
                                c = NULL;
                            }
                            else {
                                pcc_lr_table__set_head(ctx, &ctx->lrtable, p, h);
                                for (;;) {
                                    ctx->cur = p - ctx->pos;
                                    pcc_rule_set__copy(ctx->auxil, &h->eval, &h->invol);
                                    c = rule(ctx);
                                    if (c == NULL || ctx->pos + ctx->cur <= a->pos) break;
                                    pcc_lr_answer__set_chunk(ctx, a, c);
                                    a->pos = ctx->pos + ctx->cur;
                                }
                                pcc_thunk_chunk__destroy(ctx, c);
                                pcc_lr_table__set_head(ctx, &ctx->lrtable, p, NULL);
                                ctx->cur = a->pos - ctx->pos;
                                c = a->data.chunk;
                            }
                        }
                    }
                }
            }
            if (c == NULL) return PCC_FALSE;
            if (value == NULL) value = &null;
            memset(value, 0, sizeof(pcc_value_t)); /* in case */
            pcc_thunk_array__add(ctx->auxil, thunks, pcc_thunk__create_node(ctx->auxil, &c->thunks, value));
            return PCC_TRUE;
        }

      EOS
      sstream.write(<<~EOS)
        MARK_FUNC_AS_USED
        static void pcc_do_action(pcc_context_t *ctx, const pcc_thunk_array_t *thunks, pcc_value_t *value) {
            size_t i;
            for (i = 0; i < thunks->len; i++) {
                pcc_thunk_t *const thunk = thunks->buf[i];
                switch (thunk->type) {
                case PCC_THUNK_LEAF:
                    thunk->data.leaf.action(ctx, thunk, value);
                    break;
                case PCC_THUNK_NODE:
                    pcc_do_action(ctx, thunk->data.node.thunks, thunk->data.node.value);
                    break;
                default: /* unknown */
                    break;
                }
            }
        }

      EOS

      @rules.each do |rule|
        rule.codes.each do |code|
          sstream.write(<<~EOS)
            static void pcc_action_#{rule.name}_#{code.index}(#{@prefix}_context_t *__pcc_ctx, pcc_thunk_t *__pcc_in, pcc_value_t *__pcc_out) {
            #define auxil (__pcc_ctx->auxil)
            #define __ (*__pcc_out)
          EOS

          code.vars.each do |ref|
            sstream.write(<<~EOS)
              #define #{ref.reference_var} (*__pcc_in->data.leaf.values.buf[#{ref.index}])
            EOS
          end

          sstream.write(<<~EOS)
            #define _0 pcc_get_capture_string(__pcc_ctx, &__pcc_in->data.leaf.capt0)
            #define _0s ((const size_t)(__pcc_ctx->pos + __pcc_in->data.leaf.capt0.range.start))
            #define _0e ((const size_t)(__pcc_ctx->pos + __pcc_in->data.leaf.capt0.range.end))
          EOS

          code.capts.each do |capture|
            sstream.write(<<~EOS)
              #define _#{capture.index + 1} pcc_get_capture_string(__pcc_ctx, __pcc_in->data.leaf.capts.buf[#{capture.index}])
              #define _#{capture.index + 1}s ((const size_t)(__pcc_ctx->pos + __pcc_in->data.leaf.capts.buf[#{capture.index}]->range.start))
              #define _#{capture.index + 1}e ((const size_t)(__pcc_ctx->pos + __pcc_in->data.leaf.capts.buf[#{capture.index}]->range.end))
            EOS
          end

          sstream.write_code_block(code.code, 4, @iname)

          code.capts.reverse_each do |capture|
            sstream.write(<<~EOS)
              #undef _#{capture.index + 1}e
              #undef _#{capture.index + 1}s
              #undef _#{capture.index + 1}
            EOS
          end

          sstream.write(<<~EOS)
            #undef _0e
            #undef _0s
            #undef _0
          EOS

          code.vars.reverse_each do |ref|
            sstream.write(<<~EOS)
              #undef #{ref.reference_var}
            EOS
          end

          sstream.write(<<~EOS)
            #undef __
            #undef auxil
            }

          EOS
        end
      end

      @rules.each do |node|
        sstream.write(<<~EOS)
          static pcc_thunk_chunk_t *pcc_evaluate_rule_#{node.name}(pcc_context_t *ctx);
        EOS
      end
      sstream.write("\n")

      @rules.each do |node|
        g = ::Packcr::Generator.new(sstream, node, @ascii)
        sstream.write(<<~EOS)
          static pcc_thunk_chunk_t *pcc_evaluate_rule_#{node.name}(pcc_context_t *ctx) {
              pcc_thunk_chunk_t *const chunk = pcc_thunk_chunk__create(ctx);
              chunk->pos = ctx->cur;
              PCC_DEBUG(ctx->auxil, PCC_DBG_EVALUATE, \"#{node.name}\", ctx->level, chunk->pos, (ctx->buffer.buf + chunk->pos), (ctx->buffer.len - chunk->pos));
              ctx->level++;
              pcc_value_table__resize(ctx->auxil, &chunk->values, #{node.vars.length});
              pcc_capture_table__resize(ctx->auxil, &chunk->capts, #{node.capts.length});
        EOS
        if node.vars.length > 0
          sstream.write("    pcc_value_table__clear(ctx->auxil, &chunk->values);\n")
        end
        r = g.generate_code(node.expr, 0, 4, false)
        sstream.write(<<~EOS.sub(/\A.*\n/, ""))
            >
                ctx->level--;
                PCC_DEBUG(ctx->auxil, PCC_DBG_MATCH, \"#{node.name}\", ctx->level, chunk->pos, (ctx->buffer.buf + chunk->pos), (ctx->cur - chunk->pos));
                return chunk;
        EOS
        if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
          sstream.write(<<~EOS)
            L0000:;
                ctx->level--;
                PCC_DEBUG(ctx->auxil, PCC_DBG_NOMATCH, \"#{node.name}\", ctx->level, chunk->pos, (ctx->buffer.buf + chunk->pos), (ctx->cur - chunk->pos));
                pcc_thunk_chunk__destroy(ctx, chunk);
                return NULL;
          EOS
        end
        sstream.write(<<~EOS)
          }

        EOS
      end

      sstream.write(<<~EOS)
        #{prefix}_context_t *#{prefix}_create(#{auxil_def}auxil) {
            return pcc_context__create(auxil);
        }

        int #{prefix}_parse(#{prefix}_context_t *ctx, #{value_def}*ret) {
      EOS

      if !@rules.empty?
        sstream.write(<<~EOS.sub(/\A.*\n/, ""))
          >
              if (pcc_apply_rule(ctx, pcc_evaluate_rule_#{@rules[0].name}, &ctx->thunks, ret))
                  pcc_do_action(ctx, &ctx->thunks, ret);
              else
                  PCC_ERROR(ctx->auxil);
              pcc_commit_buffer(ctx);
        EOS
      end

      sstream.write(<<~EOS)
            pcc_thunk_array__revert(ctx->auxil, &ctx->thunks, 0);
            return pcc_refill_buffer(ctx, 1) >= 1;
        }

        void #{prefix}_destroy(#{prefix}_context_t *ctx) {
            pcc_context__destroy(ctx);
        }
      EOS

      eol?
      if !eof?
        sstream.putc("\n")
      end
      commit_buffer
      if @lines && !eof?
        sstream.write_line_directive(@iname, @linenum)
      end
      while refill_buffer > 0
        write_buffer(sstream)
        commit_buffer
      end
    end

    if !@errnum.zero?
      File.unlink(@hname)
      File.unlink(@sname)
      return false
    end
    true
  end
end

require "packcr/version"
