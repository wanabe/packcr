require "erb"

class Packcr
  module Util
    def unescape_string(str, is_charclass)
      if is_charclass
        str.gsub!("\\" * 2) { "\\" * 4 }
      end
      str.gsub!("\"") { "\\\"" }
      str.gsub!(/\\(.)/) do
        c = ::Regexp.last_match(1)
        case c
        when "0"
          "\\x00"
        when "'"
          c
        else
          "\\#{c}"
        end
      end
      str.gsub!(/[^\x00-\x7f]/) do
        format("\\x%02x", ::Regexp.last_match(0).ord)
      end
      str.replace "\"#{str}\"".undump
    end

    def escape_character(c)
      escape_string(c.chr)
    end

    def escape_string(str)
      str = str.b
      str.gsub(/(\0+)|(\e+)|("+)|('+)|(\\+)|((?:(?![\0\e"'\\])[ -~])+)|([\x01-\x1a\x1c-\x1f\x7f-\xff]+)/n) do
        n = ::Regexp.last_match(0).size
        next "\\0"   * n if ::Regexp.last_match(1)
        next "\\x1b" * n if ::Regexp.last_match(2)
        next "\\\""  * n if ::Regexp.last_match(3)
        next "\\'" * n if ::Regexp.last_match(4)
        next "\\\\" * n if ::Regexp.last_match(5)
        next ::Regexp.last_match(6) if ::Regexp.last_match(6)

        ::Regexp.last_match(7).dump[1..-2].downcase
      end
    end

    def dump_integer_value(value)
      if value.nil?
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

    def unify_indent_spaces(spaces)
      offset = 0
      spaces.tr!("\v\f", " ")
      spaces.gsub!(/\t+/) do
        chars = ::Regexp.last_match.pre_match.length
        o = (8 * ::Regexp.last_match(0).length) - ((offset + chars) % 8)
        offset = (7 - chars) % 8
        " " * o
      end
      spaces
    end

    def template(path, b, indent: 0, unwrap: false)
      template_path = File.join(File.dirname(__FILE__), "templates", path)
      erb = ERB.new(File.read(template_path), trim_mode: "%-")
      erb.filename = template_path
      result = erb.result(b)
      format_code(result, indent: indent, unwrap: unwrap)
    end

    def format_code(result, indent: 0, unwrap: false)
      if unwrap
        result.gsub!(/\A\{|\}\z/, "")
        indent -= 4
      end
      result.gsub!(/^(?!$)/, " " * indent)
      result.gsub!(/^( *?) {0,4}<<<</) { ::Regexp.last_match(1) }
      result
    end
  end

  extend Util
end
