require "stringio"

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

    def generate_code(node, onescape, indent, bare, reverse: false)
      if reverse
        node.generate_reverse_code(self, onescape, indent, bare)
      else
        node.generate_code(self, onescape, indent, bare)
      end
    end

    def generate_code_str(node, onescape, indent, bare, reverse: false)
      @stream, stream = StringIO.new, @stream
      begin
        return generate_code(node, onescape, indent, bare, reverse: reverse), @stream.string
      ensure
        @stream = stream
      end
    end

    def write(str)
      @stream.write(str)
    end
  end
end
