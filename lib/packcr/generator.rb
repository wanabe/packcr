
class Packcr
  class Generator
    attr_reader :ascii, :rule

    def initialize(stream, rule, ascii)
      @stream = stream
      @rule = rule
      @label = 0
      @ascii = !!ascii
    end

    def next_label
      @label += 1
    end

    def generate_code(node, onfail, indent, bare)
      node.generate_code(self, onfail, indent, bare)
    end

    def write(str)
      @stream.write(str)
    end

    def generate_block(indent, bare)
      if !bare
        @stream.write " " * indent
        @stream.write "{\n"
      end

      yield indent + 4
    ensure
      if !bare
        @stream.write " " * indent
        @stream.write "}\n"
      end
    end
  end
end
