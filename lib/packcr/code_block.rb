
class Packcr
  class CodeBlock
    attr_reader :text, :len, :line

    def initialize(text = nil, len = 0, line = nil, col = nil)
      @text = text
      @len = len
      @line = line
      @col = col
    end
  end
end
