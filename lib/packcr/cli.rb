require "packcr"
require "optparse"

class Packcr::Cli
  class << self
    def run(argv)
      new.run(argv)
    end
  end

  def run(argv)
    lang = nil
    debug = false
    opt = OptionParser.new
    opt.on("-l", "--lang=VAL") {|v| lang = v.to_sym }
    opt.on("-d", "--debug") {|v| debug = true }

    opt.parse!(argv)
    argv.each do |ifile|
      Packcr.new(ifile, lang: lang, debug: debug).run
    end
  end
end
