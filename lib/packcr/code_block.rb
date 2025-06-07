class Packcr
  class CodeBlock
    attr_reader :code, :vars, :line

    def initialize(code, lang: nil)
      if lang
        @code, @vars = Packcr.escape_variables(code, lang)
      else
        @code = code
        @vars = []
      end
    end

    def loc(line, col)
      @line = line
      @col = col
      self
    end
  end
end
