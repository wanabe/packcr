require "securerandom"

class Packcr
  class Stream
    def initialize(stream, name, line)
      @stream = stream
      @name = name
      @line = line
      @line_directive_tag = nil
    end

    def write(s, rewrite_line_directive: false)
      if rewrite_line_directive && @line_directive_tag && @line.respond_to?(:+)
        s.gsub!(@line_directive_tag) { (@line + $`.count("\n") + 1).to_s }
        @line_directive_tag = nil
      end
      @stream << s
      if @line.respond_to?(:+)
        @line += s.count("\n")
      end
    end

    def write_text(s)
      write s.gsub(/\r\n/, "\n")
    end

    def write_line_directive(fname, lineno)
      return unless @line
      if lineno.respond_to?(:+)
        write("#line #{lineno + 1} \"")
      else
        @line_directive_tag ||= "<#{SecureRandom.uuid}>"
        write("#line #{@line_directive_tag} \"")
      end

      write(Packcr.escape_string(fname))
      write("\"\n")
    end

    def write_output_line_directive
      write_line_directive(@name, @line)
    end

    def write_code_block(code, indent, fname)
      text = code.text
      ptr = text.b
      lineno = code.line

      ptr.sub!(/\A\n+/) do
        lineno += $&.length
        ""
      end
      ptr.sub!(/[ \v\f\t\r\n]*\z/, "")

      min_indent_spaces = nil
      ptr.gsub!(/^([ \v\f\t]*)([^ \v\f\t\r\n])/) do
        spaces = $1
        char = $2

        next char if char == "#"

        Packcr.unify_indent_spaces(spaces)

        if !min_indent_spaces || min_indent_spaces.length > spaces.length
          min_indent_spaces = spaces
        end

        spaces + char
      end

      if min_indent_spaces
        indent_spaces = " " * indent
        ptr.gsub!(/^#{min_indent_spaces}( *[^\n#])/) do
          "#{indent_spaces}#{$1}"
        end
      end

      return if ptr.empty?

      write_line_directive(fname, lineno)
      ptr.scan(/^(.+?)[ \v\f\t\r]*$|^\r?\n/) do
        write $1 if $1
        write "\n"
      end
      write_output_line_directive
    end

    def get_code_block(code, indent, fname)
      buf = +""
      line, stream, @stream, @line = @line, @stream, buf, @line && :uuid
      write_code_block(code, indent, fname)
      return buf
    ensure
      @line, @stream = line, stream
    end
  end
end
