require "tempfile"
require "packcr/parser"
require "packcr/broadcast"

class Packcr
  class Context
    attr_reader :lang, :root
    attr_accessor :prefix, :auxil_type, :value_type, :errnum, :capture_in_code

    def initialize(path, lines: false, debug: false, ascii: false, lang: nil)
      if !path
        raise ArgumentError, "bad path: #{path}";
      end

      @iname = path
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
        @hname = path + ".h"
        @patterns = {
          source: path + ".c",
          header: @hname
        }
        @hid = File.basename(@hname).upcase.gsub(/[^A-Z0-9]/, "_")
      when :rb
        @patterns = {
          source: path + ".rb"
        }
      else
        raise "unexpected lang: #{@lang}"
      end

      @lines = !!lines
      @ascii = !!ascii
      @utf8 = !ascii

      @errnum = 0

      @codes = {}
      @root = Node::RootNode.new

      if block_given?
        yield(self)
      end
    end

    def code(name)
      @codes[name] ||= []
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

    def pass_value_code(var)
      case @lang
      when :c
        "__ = #{var};"
      when :rb
        "____ = #{var}"
      end
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

    def parse_all
      File.open(@iname, "rb") do |r|
        parser = Packcr::Parser.new(self, r, debug: @debug)
        nil while parser.parse
      end

      if !code(:location).empty?
        @location = true
      end

      @root.setup(self)

      if @debug
        @root.debug_dump
        dump_options
      end

      @errnum.zero?
    end

    def generate
      results = []

      @patterns.each do |template, ofile|
        result = Tempfile.new
        result.unlink
        results << [ofile, result]
        stream = Packcr::Stream.new(result, ofile, @lines ? 0 : nil)
        stream.write Packcr.template("context/#{template}.#{@lang}.erb", binding), rewrite_line_directive: true

        if !@errnum.zero?
          results.each do |_, result|
            result.close
          end
          return false
        end
      end

      results.each do |(name, result)|
        result.rewind
        open(name, "wt") do |f|
          IO.copy_stream(result, f)
        end
      end
      true
    end
  end
end
