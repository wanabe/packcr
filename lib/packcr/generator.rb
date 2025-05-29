class Packcr
  class Generator
    attr_reader :ascii, :rule, :location, :lang, :level

    def initialize(rule, ascii, location, lang = :c)
      @rule = rule
      @label = 0
      @ascii = !!ascii
      @location = !!location
      @lang = lang
      @level = 0
    end

    def next_label
      @label += 1
    end

    def generate_code(node, onescape, indent, bare, reverse: false, oncut: nil)
      stream = @stream
      @stream = +""
      @level += 1
      begin
        if reverse
          code = node.generate_reverse_code(self, onescape, indent, bare, oncut: oncut)
        else
          code = node.generate_code(self, onescape, indent, bare, oncut: oncut)
        end
        write Packcr.format_code(code, indent: indent, unwrap: bare)
        @stream
      ensure
        @level -= 1
        @stream = stream
      end
    end

    def write(str)
      @stream << str
    end
  end
end
