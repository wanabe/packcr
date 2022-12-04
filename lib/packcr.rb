class Packcr
  def initialize(path)
    @path = path.to_s
  end

  def run
    Context.new(@path.to_s) do |ctx|
      if !ctx.parse || !ctx.generate
        raise "PackCC error"
      end
    end
  end
end

require "packcr.so"
require "packcr/version"
