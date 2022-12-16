
class Packcr
  module Util
    def is_identifier_string(str)
      str.match?(/\A(?!\d)\w+\z/)
    end

    def unescape_string(str, is_charclass)
      if is_charclass
        str.gsub!("\\" * 2) { "\\" * 4 }
      end
      str.gsub!(/\\(.)/) do
        c = $1
        case c
        when "0"
          "\\x00"
        when "'"
          c
        else
          "\\#{c}"
        end
      end
      str.replace "\"#{str}\"".undump
    end

    def escape_character(c)
      escape_string(c.chr)
    end

    def escape_string(str)
      str = str.b
      str.gsub(/(\0+)|(\e+)|("+)|('+)|(\\+)|((?:(?![\0\e"'\\])[ -~])+)|([\x01-\x1a\x1c-\x1f\x7f-\xff]+)/n) do
        n = $&.size
        next "\\0"   * n if $1
        next "\\x1b" * n if $2
        next "\\\""  * n if $3
        next "\\\'"  * n if $4
        next "\\\\"  * n if $5
        next $6 if $6
        $7.dump[1..-2].downcase
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
      $stdout.print escape_string(str)
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

    def template(path, b, indent: 0, unwrap: false)
      template_path = File.join(File.dirname(__FILE__), "templates", path)
      result = ERB.new(File.read(template_path), trim_mode: "%-").result(b)
      if unwrap
        result.gsub!(/\A\{|\}\z/, "")
        indent -= 4
      end
      result.gsub!(/^(?!$)/, " " * indent)
      result.gsub!(/^( *?) {0,4}<<<</) { $1 }
      result
    end
  end

  extend Util
end