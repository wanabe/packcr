
class Packcr
  class Generator
    attr_reader :ascii, :rule

    def initialize(rule, ascii)
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

    def generate_code_str(node, onfail, indent, bare)
      @stream, stream = StringIO.new, @stream
      begin
        return generate_code(node, onfail, indent, bare), @stream.string
      ensure
        @stream = stream
      end
    end

    def write(str)
      @stream.write(str)
    end
  end
end
