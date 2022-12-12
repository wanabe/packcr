
class Packcr
  module Util
    def is_identifier_string(str)
      str =~ /\A(?!\d)\w+\z/
    end

    def unescape_string(str, is_charclass)
      if is_charclass
        str.gsub!("\\" * 2) { "\\" * 4 }
      end
      str.replace "\"#{str}\"".undump
    end

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

    def dump_integer_value(value)
      if value == nil
        $stdout.print "void"
      else
        $stdout.print value
      end
    end

    def dump_escaped_string(str)
      if !str
        $stdout.print "null"
        return
      end
      str.each_byte do |c|
        $stdout.print escape_character(c)
      end
    end

    def find_first_trailing_space(str, s, e)
      i = j = s
      while i < e
        case str[i]
        when " ", "\v", "\f", "\t"
          i += 1
          next
        when "\n"
          return j, i + 1
        when "\r"
          if (i + 1 < e && str[i + 1] == "\n")
            i += 1
          end
          return j, i + 1
        else
          j = i + 1
          i += 1
        end
      end
      return j, e
    end

    def find_trailing_blanks(str)
      j = 0
      i = 0
      while str[i]
        if (
              str[i] != " "  &&
              str[i] != "\v" &&
              str[i] != "\f" &&
              str[i] != "\t" &&
              str[i] != "\n" &&
              str[i] != "\r"
            )
          j = i + 1
        end
        i += 1
      end
      return j
    end

    def count_indent_spaces(str, s, e)
      n = 0
      i = s
      while i < e
        case str[i]
        when " ", "\v", "\f"
          n += 1
        when "\t"
          n = (n + 8) & ~7
        else
          return n, i
        end
        i += 1
      end
      return n, e
    end
  end

  extend Util
end