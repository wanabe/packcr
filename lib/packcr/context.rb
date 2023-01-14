require "tempfile"
require "packcr/parser"
require "packcr/broadcast"

class Packcr
  class Context
    attr_reader :rules, :rulehash, :lang
    attr_accessor :prefix, :auxil_type, :value_type, :errnum, :capture_in_code

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
        @hname = path + ".h"
        @patterns = {
          source: path + ".c",
          header: @hname
        }
        @broadcasts = {
          ecommon: %i[eheader esource],
          common: %i[header source],
        }
        @hid = File.basename(@hname).upcase.gsub(/[^A-Z0-9]/, "_")
      when :rb
        @patterns = {
          source: path + ".rb"
        }
        @broadcasts = {}
      else
        raise "unexpected lang: #{@lang}"
      end

      @lines = !!lines
      @ascii = !!ascii
      @utf8 = !ascii

      @errnum = 0

      @codes = {}
      @rules = []
      @rulehash = {}
      @implicit_rules = []

      if block_given?
        yield(self)
      end
    end

    def code(name)
      return @codes[name] if @codes[name]
      names = @broadcasts[name]
      if !names
        @codes[name] = []
      else
        arrays = names.map{ |n| code(n) }
        @codes[name] = BroadCast.new(arrays)
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

    def make_rulehash
      @rules.each do |rule|
        @rulehash[rule.name] = rule
      end
      @implicit_rules.each do |rule|
        next if @rulehash[rule.name]
        @rules << rule
        @rulehash[rule.name] = rule
      end
    end

    def rule(name)
      @rulehash[name]
    end

    def implicit_rule(name)
      case name
      when "EOF"
        expr = Packcr::Node::EofNode.new
      else
        raise "Unexpected implicit rule: #{name.inspect}"
      end
      rule = Packcr::Node::RuleNode.new(expr, name)
      @implicit_rules << rule
    end

    def parse_all
      nil while @parser.parse

      if !code(:location).empty?
        @location = true
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
