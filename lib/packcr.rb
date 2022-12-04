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

class Packcr::Context
  def init(path)
    @iname = path
    dirname = File.dirname(path)
    basename = File.basename(path, ".*")
    if dirname == "."
      path = basename
    else
      path = File.join(dirname, basename)
    end
    @sname = path + ".c"
    @hname = path + ".h"
    @hid = File.basename(@hname).upcase.gsub(/[^A-Z0-9]/, "_")
  end
end

require "packcr/version"
