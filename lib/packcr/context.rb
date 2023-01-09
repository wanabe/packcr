require "packcr/parser"

class Packcr
  class Context
    attr_reader :rules, :rulehash, :lang
    attr_reader :esource, :ecommon, :source, :lheader, :lsource, :header, :common, :location, :init
    attr_accessor :prefix, :auxil_type, :value_type

    def initialize(path, lines: false, debug: false, ascii: false, lang: nil)
      if !path
        raise ArgumentError, "bad path: #{path}";
      end

      @iname = path
      @ifile = File.open(path, "rb")
      @parser = Packcr::Parser.new(self, @ifile, debug: debug)
      @debug = debug

      dirname = File.dirname(path)
      basename = File.basename(path, ".*")
      if !lang
        lang = File.extname(basename)[1..-1]&.to_sym
        if lang
          basename = File.basename(basename, ".*")
        else
          lang = :c
        end
      end
      if dirname == "."
        path = basename
      else
        path = File.join(dirname, basename)
      end

      @lang = lang.to_sym
      case @lang
      when :c
        @sname = path + ".c"
        @hname = path + ".h"
        @hid = File.basename(@hname).upcase.gsub(/[^A-Z0-9]/, "_")
      when :rb
        @sname = path + ".rb"
        @hname = nil
      else
        raise "unexpected lang: #{@lang}"
      end

      @lines = !!lines
      @ascii = !!ascii
      @utf8 = !ascii

      @errnum = 0

      @esource = []
      @eheader = []
      @source = []
      @header = []
      @lheader = []
      @lsource = []
      @location = []
      @init = []
      @rules = []
      @rulehash = {}

      if block_given?
        yield(self)
      end
    end

    def inspect
      "#<#{self.class}:0x%016x>" % object_id
    end

    def error(line, col, message)
      warn "#{@iname}:#{line}:#{col}: #{message}"
      @errnum += 1
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

    def class_name
      prefix.gsub(/(?:_|^|(\W))([a-z])/) { "#{$1}#{$2}".upcase }
    end

    def auxil_def
      type = auxil_type
      "#{type}#{type =~ /\*$/ ? "" : " "}"
    end

    def value_def
      type = value_type
      "#{type}#{type =~ /\*$/ ? "" : " "}"
    end

    def dump_options
      $stdout.print <<~EOS
        value_type: '#{value_type}'
        auxil_type: '#{auxil_type}'
        prefix: '#{prefix}'
      EOS
    end

    def make_rulehash
      @rules.each do |rule|
        @rulehash[rule.name] = rule
      end
    end

    def rule(name)
      @rulehash[name]
    end

    def parse_all
      nil while @parser.parse

      if @location.empty?
        @location = nil
      end

      make_rulehash
      @rules.each do |rule|
        rule.setup
        rule.expr.link_references(self)
      end
      @rules[1..-1]&.each do |rule|
        if rule.ref == 0
          error rule.line + 1, rule.col + 1, "Never used rule '#{rule.name}'"
        elsif rule.ref < 0 # impossible?
          error rule.line + 1, rule.col + 1, "Multiple definition of rule '#{rule.name}'"
        end
      end

      @rules.each do |rule|
        rule.verify(self)
      end

      if @debug
        @rules.each(&:debug_dump)
        dump_options
      end

      @errnum.zero?
    end

    def generate
      if @hname
        File.open(@hname, "wt") do |hio|
          hstream = ::Packcr::Stream.new(hio, @hname, @lines ? 0 : nil)

          hstream.write Packcr.template("context/header.#{@lang}.erb", binding), rewrite_line_directive: true
        end
      end

      File.open(@sname, "wt") do |sio|
        sstream = ::Packcr::Stream.new(sio, @sname, @lines ? 0 : nil)

        sstream.write Packcr.template("context/source.#{@lang}.erb", binding), rewrite_line_directive: true
      end

      if !@errnum.zero?
        File.unlink(@hname) if @name
        File.unlink(@sname)
        return false
      end
      true
    end
  end
end
