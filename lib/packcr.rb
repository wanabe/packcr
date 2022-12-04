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

class Packcr::Stream
  def initialize(io, name, line)
    @io = io
    @name = name
    @line = line
  end
end

class Packcr::Context
  def init(path)
    @iname = path
    @ifile = File.open(path, "rb")
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

    @errnum = 0
    @linenum = 0
    @charnum = 0
    @linepos = 0
    @bufpos = 0
    @bufcur = 0

    @esource = []
    @eheader = []
    @source = []
    @header = []
    @rulehash = {}
  end

  def value_type
    @value_type || "int"
  end

  def auxil_type
    @auxil_type || "void *"
  end

  def prefix
    @prefix || "pcc"
  end

  def generate
    File.open(@sname, "wt") do |sio|
      File.open(@hname, "wt") do |hio|
        sstream = ::Packcr::Stream.new(sio, @sname, @lines ? 0 : -1)
        hstream = ::Packcr::Stream.new(hio, @hname, @lines ? 0 : -1)
        _generate(sstream, hstream)
      end
    end

    if !@errnum.zero?
      File.unlink(@hname)
      File.unlink(@sname)
      return false
    end
    true
  end
end

require "packcr/version"
