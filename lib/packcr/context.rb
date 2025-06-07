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
        @hname = "#{path}.h"
        @patterns = {
          get_source_code: "#{path}.c",
          get_header_code: @hname,
        }
        @hid = File.basename(@hname).upcase.gsub(/[^A-Z0-9]/, "_")
      when :rb, :rs
        @patterns = {
          get_source_code: "#{path}.#{@lang}",
        }
      else
        raise "unexpected lang: #{@lang}"
      end

      @lines = !!lines
      @ascii = !!ascii
      @utf8 = !ascii

      @errnum = 0

      @code_blocks = {}
      @root = Node::RootNode.new

      return unless block_given?

      yield(self)
    end

    def code_block(name)
      @code_blocks[name] ||= []
    end

    def inspect
      format("#<%s:0x%016x>", self.class, object_id)
    end

    def error(line, col, message)
      warn "#{@iname}:#{line}:#{col}: #{message}"
      @errnum += 1
    end

    def value_type
      return @value_type if @value_type

      case @lang
      when :c
        "int"
      when :rs
        "i32"
      end
    end

    def auxil_type
      @auxil_type || "void *"
    end

    def prefix
      @prefix || "packcr"
    end

    def pass_value_code(var)
      case @lang
      when :c, :rb, :rs
        "$$ = #{var};"
      end
    end

    def line_comment_code(line)
      line = line.chomp
      case @lang
      when :c
        line.gsub("*/", "* /")
        "/* #{line} */"
      when :rb
        "# #{line}"
      end
    end

    def class_name
      prefix.gsub(/(?:_|^|(\W))([a-z])/) { "#{::Regexp.last_match(1)}#{::Regexp.last_match(2)}".upcase }
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

      if !code_block(:location).empty?
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

      @patterns.each do |meth, ofile|
        result = Tempfile.new
        result.unlink
        results << [ofile, result]
        stream = Packcr::Stream.new(result, ofile, @lines ? 0 : nil)
        stream.write Packcr.format_code(public_send(meth, @lang, stream)), rewrite_line_directive: true

        next if @errnum.zero?

        results.each_value(&:close)
        return false
      end

      results.each do |(name, result)|
        result.rewind
        File.open(name, "wt") do |f|
          IO.copy_stream(result, f)
        end
      end
      true
    end
  end
end

require "packcr/generated/context"
