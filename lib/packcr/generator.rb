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

    def generate_code(node, onescape, indent, bare, reverse: false, oncut: nil)
      if reverse
        node.generate_reverse_code(self, onescape, indent, bare, oncut: oncut)
      else
        node.generate_code(self, onescape, indent, bare, oncut: oncut)
      end
    end

    def generate_code_str(node, onescape, indent, bare, reverse: false, oncut: nil)
      @stream, stream = StringIO.new, @stream
      begin
        generate_code(node, onescape, indent, bare, reverse: reverse, oncut: oncut)
        @stream.string
      ensure
        @stream = stream
      end
    end

    def write(str)
      @stream.write(str)
    end
  end
end
