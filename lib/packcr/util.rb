
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

    def find_trailing_blanks(str)
      str =~ /[ \v\f\t\n\r]*\z/
    end

    def unify_indent_spaces(spaces)
      offset = 0
      spaces.tr!("\v\f", " ")
      spaces.gsub!(/\t+/) do
        chars = $`.length
        o = 8 * $&.length - (offset + chars) % 8
        offset = (7 - chars) % 8
        " " * o
      end
      spaces
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