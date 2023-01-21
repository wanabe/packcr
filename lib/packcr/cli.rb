require "packcr"
require "optparse"

class Packcr
  class Cli
    class << self
      def run(argv)
        new.run(argv)
      end
    end

    def run(argv)
      lang = nil
      debug = false
      ascii = false
      opt = OptionParser.new
      opt.on("-l", "--lang=VAL") { |v| lang = v.to_sym }
      opt.on("-d", "--debug") { |_v| debug = true }
      opt.on("-a", "--ascii") { |_v| ascii = true }

      opt.parse!(argv)
      argv.each do |ifile|
        ::Packcr.new(ifile, lang: lang, debug: debug, ascii: ascii).run
      end
    end
  end
end
