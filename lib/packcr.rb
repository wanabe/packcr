class Packcr
end

require "packcr/util"
require "packcr/code_block"
require "packcr/stream"
require "packcr/generator"
require "packcr/buffer"
require "packcr/node"
require "packcr/context"
require "packcr/version"

class Packcr
  CODE_REACH__BOTH = 0
  CODE_REACH__ALWAYS_SUCCEED = 1
  CODE_REACH__ALWAYS_FAIL = -1

  def initialize(path, **opt)
    @path = path.to_s
    @opt = opt
  end

  def run
    Context.new(@path.to_s, **@opt) do |ctx|
      if !ctx.parse
        raise "PackCR error: can't parse"
      end
      if !ctx.generate
        raise "PackCR error: can't generate"
      end
    end
  end
end
