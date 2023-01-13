class Packcr
  class Generator
    attr_reader :ascii, :rule, :location, :lang

    def initialize(rule, ascii, location, lang = :c)
      @rule = rule
      @label = 0
      @ascii = !!ascii
      @location = !!location
      @lang = lang
    end

    def next_label
      @label += 1
    end

    def generate_code(node, onescape, indent, bare, reverse: false, oncut: nil)
      @stream, stream = +"", @stream
      begin
        if reverse
          node.generate_reverse_code(self, onescape, indent, bare, oncut: oncut)
        else
          node.generate_code(self, onescape, indent, bare, oncut: oncut)
        end
        @stream
      ensure
        @stream = stream
      end
    end

    def write(str)
      @stream << str
    end
  end
end
