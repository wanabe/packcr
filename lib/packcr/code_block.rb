class Packcr
  class CodeBlock
    attr_reader :text, :line

    def initialize(text = nil, line = nil, col = nil)
      @text = text
      @line = line
      @col = col
    end
  end
end
