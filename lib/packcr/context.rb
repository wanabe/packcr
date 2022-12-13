require "erb"
require "stringio"

class Packcr
  class Context
    def initialize(path, lines: false, debug: false, ascii: false)
      if !path
        raise ArgumentError, "bad path: #{path}";
      end

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

      @lines = !!lines
      @debug = !!debug
      @ascii = !!ascii

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
      @rules = []
      @rulehash = {}
      @buffer = Packcr::Buffer.new

      if block_given?
        yield(self)
      end
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

    def auxil_def
      type = auxil_type
      "#{type}#{type =~ /\*$/ ? "" : " "}"
    end

    def value_def
      type = value_type
      "#{type}#{type =~ /\*$/ ? "" : " "}"
    end

    def eof?
      refill_buffer(1) < 1
    end

    def eol?
      return false if eof?

      case @buffer[@bufcur]
      when 0xa
        @bufcur += 1
        @linenum += 1
        @charnum = 0
        @linepos = @bufpos + @bufcur
        true
      when 0xd
        @bufcur += 1
        if !eof? && @buffer[@bufcur] == 0xd
          @bufcur += 1
        end
        @linenum += 1
        @charnum = 0
        @linepos = @bufpos + @bufcur
        true
      else
        false
      end
    end

    def column_number
      unless @bufpos + @bufcur >= @linepos
        raise "invalid position: expect #{@bufpos + @bufcur} >= #{@linepos}"
      end
      offset = @linepos > @bufpos ? @linepos - @bufpos : 0
      if @ascii
        @charnum + @bufcur - offset
      else
        @charnum + @buffer.count_characters(offset, @bufcur)
      end
    end

    def make_rulehash
      @rules.each do |rule|
        @rulehash[rule.name] = rule
      end
    end

    def refill_buffer(num = nil)
      while !num || @buffer.len - @bufcur < num
        c = @ifile.getc
        break if c.nil?
        @buffer.add(c.ord)
      end

      return @buffer.len - @bufcur
    end

    def commit_buffer
      if @buffer.len < @bufcur
        raise "unexpected buffer state: length(#{@buffer.len}), current(#{@bufcur})"
      end
      if @linepos < @bufpos + @bufcur
        count = @ascii ? @bufcur : @buffer.count_characters(0, @bufcur)
        @charnum += count
      end
      @buffer.add_pos(@bufcur)
      @bufpos = @bufpos + @bufcur
      @bufcur = 0
    end

    def write_buffer(stream)
      n = @buffer.len
      text = @buffer.to_s
      if n > 0 && text[-1] == "\r"
        text = text[0..-2]
      end
      stream.write_text(text)
      @bufcur = n
    end

    def match_character(ch)
      if refill_buffer(1) >= 1
        if @buffer[@bufcur].ord == ch.ord
          @bufcur += 1
          return true
        end
      end
      false
    end

    def match_character_range(min, max)
      if refill_buffer(1) >= 1
        c = @buffer[@bufcur].ord
        if (min..max) === c
          @bufcur += 1
          return true
        end
      end
      false
    end

    def match_character_set(chars)
      if refill_buffer(1) >= 1
        c = @buffer[@bufcur].ord
        chars.each_byte do |ch|
          if c == ch
            @bufcur += 1
            return true
          end
        end
      end
      false
    end

    def match_string(str)
      n = str.length
      if refill_buffer(n) >= n
        if @buffer.to_s[@bufcur, n] == str
          @bufcur += n
          return true
        end
      end
      false
    end

    def match_blank
      match_character_set(" \t\v\f")
    end

    def match_character_any
      if refill_buffer(1) >= 1
        @bufcur += 1
        return true
      end
      false
    end

    def match_section_line_(head)
      if match_string(head)
        while !eol? && !eof?
          match_character_any
        end
        return true
      end
      false
    end

    def match_section_line_continuable_(head)
      if match_string(head)
        while !eof?
          pos = @bufcur
          if eol?
            if @buffer[pos - 1] != "\\".ord
              break
            end
          else
            match_character_any
          end
        end
        return true
      end
      false
    end

    def match_section_block_(left, right, name)
      l = @linenum
      m = column_number
      if match_string(left)
        while !match_string(right)
          if eof?
            warn "#{@iname}:#{l + 1}:#{m + 1}: Premature EOF in #{name}\n"
            @errnum += 1
            break
          end
          if !eol?
            match_character_any
          end
        end
        return true
      end
      false
    end

    def match_quotation_(left, right, name)
      l = @linenum
      m = column_number
      if match_string(left)
        while !match_string(right)
          if eof?
            warn "#{@iname}:#{l + 1}:#{m + 1}: Premature EOF in #{name}\n"
            @errnum += 1
            break
          end
          if match_character("\\".ord)
            if !eol?
              match_character_any
            end
          else
            if eol?
              warn "#{@iname}:#{l + 1}:#{m + 1}: Premature EOF in #{name}\n"
              @errnum += 1
              break
            end
            match_character_any
          end
        end
        return true
      end
      false
    end

    def match_directive_c
      match_section_line_continuable_("#")
    end

    def match_comment
      match_section_line_("#")
    end

    def match_comment_c
      match_section_block_("/*", "*/", "C comment")
    end

    def match_comment_cxx
      match_section_line_("//")
    end

    def match_quotation_single
      match_quotation_("\'", "\'", "single quotation")
    end

    def match_quotation_double
      match_quotation_("\"", "\"", "double quotation")
    end

    def match_character_class
      match_quotation_("[", "]", "character class")
    end

    def match_spaces
      n = 0
      while match_blank || eol? || match_comment
        n += 1
      end
      n > 0
    end

    def match_number
      if match_character_range("0".ord, "9".ord)
        while match_character_range("0".ord, "9".ord)
          return true
        end
      end
      return false
    end

    def match_identifier
      if match_character_range("a".ord, "z".ord) || match_character_range("A".ord, "Z".ord) || match_character("_".ord)
        nil while match_character_range("a".ord, "z".ord) || match_character_range("A".ord, "Z".ord) || match_character_range("0".ord, "9".ord) || match_character("_".ord)
        return true
      end
      false
    end

    def match_code_block
      l = @linenum
      m = column_number
      if match_character("{".ord)
        d = 1
        while true
          if eof?
            warn "#{@iname}:#{l + 1}:#{m + 1}: Premature EOF in code block\n"
            @errnum += 1
            break
          end
          if match_directive_c || match_comment_c || match_comment_cxx || match_quotation_single || match_quotation_double
            next
          end
          if match_character("{".ord)
            d += 1
          elsif match_character("}".ord)
            d -= 1
            if d == 0
              break
            end
          else
            if !eol?
              if match_character("$".ord)
                @buffer[@bufcur - 1] = "_".ord
              else
                match_character_any
              end
            end
          end
        end
        return true
      end
      return false
    end

    def match_footer_start
      match_string("%%")
    end

    def dump_options
      $stdout.print <<~EOS
        value_type: '#{value_type}'
        auxil_type: '#{auxil_type}'
        prefix: '#{prefix}'
      EOS
    end

    def verify_variables(node, vars = [])
      if !node
        return
      end

      case node
      when Packcr::Node::RuleNode
        raise "Internal error"
      when Packcr::Node::ReferenceNode
        if node.index != nil
          found = vars.any? do |var|
            unless var.is_a?(Packcr::Node::ReferenceNode)
              raise "unexpected var: #{var.class}"
            end
            node.index == var.index
          end
          if !found
            vars.push(node)
          end
        end
      when Packcr::Node::StringNode, Packcr::Node::CharclassNode
      when Packcr::Node::QuantityNode
        verify_variables(node.expr, vars)
      when Packcr::Node::PredicateNode
        verify_variables(node.expr, vars)
      when Packcr::Node::SequenceNode
        node.nodes.each do |child_node|
          verify_variables(child_node, vars)
        end
      when Packcr::Node::AlternateNode
        m = vars.length
        nodes = node.nodes
        v = vars.dup
        node.nodes.each do |child_node|
          v = v[0, m]
          verify_variables(child_node, v)
          v[m...-1].each do |added_node|
            found = vars[m...-1].any? do |added_var|
              added_node.index == added_var.index
            end
            if !found
              vars.push(added_node)
            end
          end
        end
      when Packcr::Node::CaptureNode
        verify_variables(node.expr, vars)
      when Packcr::Node::ExpandNode
      when Packcr::Node::ActionNode
        node.vars = vars
      when Packcr::Node::ErrorNode
        node.vars = vars
        verify_variables(node.expr, vars)
      else
        raise "Internal error"
      end
    end

    def verify_captures(node, capts = [])
      if !node
        return
      end

      case node
      when Packcr::Node::RuleNode
        raise "Internal error"
      when Packcr::Node::ReferenceNode, Packcr::Node::StringNode, Packcr::Node::CharclassNode
      when Packcr::Node::QuantityNode
        verify_captures(node.expr, capts)
      when Packcr::Node::PredicateNode
        verify_captures(node.expr, capts)
      when Packcr::Node::SequenceNode
        node.nodes.each do |child_node|
          verify_captures(child_node, capts)
        end
      when Packcr::Node::AlternateNode
        m = capts.length
        nodes = node.nodes
        v = capts.dup
        node.nodes.each do |child_node|
          v = v[0, m]
          verify_captures(child_node, v)
          v[m...-1].each do |added_node|
            capts.push(added_node)
          end
        end
      when Packcr::Node::CaptureNode
        verify_captures(node.expr, capts)
        capts.push(node)
      when Packcr::Node::ExpandNode
        found = capts.any? do |capt|
          unless capt.is_a?(Packcr::Node::CaptureNode)
            raise "unexpected capture: #{capt.class}"
          end
          node.index == capt.index
        end
        if !found && node.index != Packcr::nil
          warn "#{@iname}:#{node.line + 1}:#{node.col + 1}: Capture #{node.index + 1} not available at this position\n"
          @errnum += 1
        end
      when Packcr::Node::ActionNode
        node.capts = capts
      when Packcr::Node::ErrorNode
        node.capts = capts
        verify_captures(node.expr, capts)
      else
        raise "Internal error"
      end
    end

    def link_references(node)
      if !node
        return
      end

      case node
      when Packcr::Node::RuleNode
        raise "Internal error"
      when Packcr::Node::ReferenceNode
        name = node.name
        rule = @rulehash[name]
        if !rule
          warn "#{@iname}:#{node.line + 1}:#{node.col + 1}: No definition of rule '#{node.name}'\n"
          @errnum += 1
        else
          unless rule.is_a?(Packcr::Node::RuleNode)
            raise "unexpected node type #{rule.class}"
          end
          rule.add_ref
          node.rule = rule
        end
      when Packcr::Node::StringNode, Packcr::Node::CharclassNode
      when Packcr::Node::QuantityNode
        link_references(node.expr)
      when Packcr::Node::PredicateNode
        link_references(node.expr)
      when Packcr::Node::SequenceNode
        node.nodes.each do |child_node|
          link_references(child_node)
        end
      when Packcr::Node::AlternateNode
        node.nodes.each do |child_node|
          link_references(child_node)
        end
      when Packcr::Node::CaptureNode
        link_references(node.expr)
      when Packcr::Node::ExpandNode, Packcr::Node::ActionNode
      when Packcr::Node::ErrorNode
        link_references(node.expr)
      else
        raise "Internal error"
      end
    end

    def parse_directive_include(name, *outputs)
      if !match_string(name)
        return false
      end

      match_spaces

      pos = @bufcur
      l = @linenum
      m = column_number
      if match_code_block
        q = @bufcur
        match_spaces
        outputs.each do |output|
          code = Packcr::CodeBlock.new(@buffer.to_s[pos + 1, q - pos - 2], q - pos - 2, l, m)
          output.push(code)
        end
      else
        warn "#{@iname}:#{l + 1}:#{m + 1}: Illegal #{name} syntax\n"
        @errnum += 1
      end
      true
    end

    def parse_directive_string(name, varname, must_not_be_empty: false, must_not_be_void: false, must_be_identifier: false)
      l = @linenum
      m = column_number
      if !match_string(name)
        return false
      end

      match_spaces
      pos = @bufcur
      lv = @linenum
      mv = column_number
      s = nil
      if match_quotation_single || match_quotation_double
        q = @bufcur
        match_spaces
        s = @buffer.to_s[pos + 1, q - pos - 2]
        if !Packcr.unescape_string(s, false)
          warn "#{@iname}:#{lv + 1}:#{mv + 1}: Illegal escape sequence"
          @errnum += 1
        end
      else
        warn "#{@iname}:#{l + 1}:#{m + 1}: Illegal #{name} syntax"
        @errnum += 1
      end

      if s
        valid = true
        s.sub!(/\A\s+/, "")
        s.sub!(/\s+\z/, "")
        is_empty = must_not_be_empty && s !~ /[^\s]/
        if is_empty
          warn "#{@iname}:#{lv + 1}:#{mv + 1}: Empty string"
          @errnum += 1
          vaild = false
        end
        if must_not_be_void && s == "void"
          warn "#{@iname}:#{lv + 1}:#{mv + 1}: 'void' not allowed"
          @errnum += 1
          vaild = false
        end
        if !is_empty && must_be_identifier && !Packcr.is_identifier_string(s)
          warn "#{@iname}:#{lv + 1}:#{mv + 1}: Invalid identifier"
          @errnum += 1
          valid = false
        end
        if instance_variable_get(varname) != nil
          warn "#{@iname}:#{l + 1}:#{m + 1}: Multiple #{name} definition"
          @errnum += 1
          valid
        end
        if valid
          instance_variable_set(varname, s)
        end
      end
      return true
    end

    class StopParsing < StandardError
    end

    def parse_primary(rule)
      pos = @bufcur
      l = @linenum
      m = column_number
      n = @charnum
      o = @linepos
      if match_identifier
        q = @bufcur
        r = s = nil
        match_spaces
        if match_character(":".ord)
          match_spaces
          r = @bufcur
          if !match_identifier
            raise StopParsing
          end
          s = @bufcur
          match_spaces
        end
        if match_string("<-")
          raise StopParsing
        end

        n_p = Packcr::Node::ReferenceNode.new
        if r == nil
          name = @buffer.to_s
          name = name[pos, q - pos]
          unless q >= pos
            raise "Internal error"
          end
          n_p.var = nil
          n_p.index = nil
          n_p.name = name
        else
          var = @buffer.to_s
          var = var[pos, q - pos]
          unless s != nil # s should have a valid value when r has a valid value
            raise "Internal error"
          end
          unless q >= pos
            raise "Internal error"
          end

          n_p.var = var
          if var.ord == "_".ord
            warn "#{@iname}:#{l + 1}:#{m + 1}: Leading underscore in variable name '#{var}'"
            @errnum += 1
          end

          i = rule.vars.index do |ref|
            unless ref.is_a?(Packcr::Node::ReferenceNode)
              raise "Unexpected node type: #{ref.class}"
            end
            var == ref.var
          end
          if !i
            i = rule.vars.length
            rule.add_var(n_p)
          end
          n_p.index = i
          unless s >= r
            raise "Internal error"
          end

          name = @buffer.to_s
          name = name[r, s - r]
          n_p.name = name
        end
        n_p.line = l
        n_p.col = m
      elsif match_character("(")
        match_spaces
        n_p = parse_expression(rule)
        if !n_p
          raise StopParsing
        end
        if !match_character(")")
          raise StopParsing
        end
        match_spaces
      elsif match_character("<")
        capts = rule.capts
        match_spaces
        n_p = Packcr::Node::CaptureNode.new
        n_p.index = capts.length
        rule.add_capt(n_p)
        expr = parse_expression(rule)
        n_p.expr = expr
        if !expr || !match_character(">")
          rule.capts = rule.capts[0, n_p.index]
          raise StopParsing
        end
        match_spaces
      elsif match_character("$")
        match_spaces
        pos2 = @bufcur
        if match_number
          q = @bufcur
          s = @buffer.to_s
          s = s[pos2, q - pos2]
          match_spaces
          n_p = Packcr::Node::ExpandNode.new
          unless q >= pos2
            raise StopParsing
          end
          index = s.to_i
          n_p.index = index
          if index == nil
            warn "#{@iname}:#{l + 1}:#{m + 1}: Invalid unsigned number '#{s}'"
            @errnum += 1
          elsif index == 0
            warn "#{@iname}:#{l + 1}:#{m + 1}: 0 not allowed"
            @errnum += 1
          elsif s.ord == "0".ord
            warn "#{@iname}:#{l + 1}:#{m + 1}: 0-prefixed number not allowed"
            @errnum += 1
            n_p.index = 0
          end
          if index > 0 && index != nil
            n_p.index = index - 1
            n_p.line = l
            n_p.col = m
          end
        else
          raise StopParsing
        end
      elsif match_character(".")
        match_spaces
        n_p = Packcr::Node::CharclassNode.new
        n_p.value = nil
        if !@ascii
          @utf8 = true
        end
      elsif match_character_class
        q = @bufcur
        charclass = @buffer.to_s
        charclass = charclass[pos + 1, q - pos - 2]
        match_spaces
        n_p = Packcr::Node::CharclassNode.new
        Packcr.unescape_string(charclass, true)
        if !@ascii
          charclass.force_encoding(Encoding::UTF_8)
        end
        if !@ascii && !charclass.valid_encoding?
          warn "#{@iname}:#{l + 1}:#{m + 1}: Invalid UTF-8 string"
          @errnum += 1
        end
        if !@ascii && !charclass.empty?
          @utf8 = true
        end
        n_p.value = charclass
      elsif match_quotation_single || match_quotation_double
        q = @bufcur
        string = @buffer.to_s
        string = string[pos + 1, q - pos - 2]
        match_spaces
        n_p = ::Packcr::Node::StringNode.new
        Packcr.unescape_string(string, true)
        if !@ascii
          string.force_encoding(Encoding::UTF_8)
        end
        if !@ascii && !string.valid_encoding?
          warn "#{@iname}:#{l + 1}:#{m + 1}: Invalid UTF-8 string"
          @errnum += 1
        end
        n_p.value = string
      elsif match_code_block
        q = @bufcur
        text = @buffer.to_s
        text = text[pos + 1, q - pos - 2]
        codes = rule.codes
        match_spaces
        n_p = Packcr::Node::ActionNode.new
        n_p.code = Packcr::CodeBlock.new(text, Packcr.find_trailing_blanks(text), l, m)
        n_p.index = codes.length
        codes.push(n_p)
      else
        raise StopParsing
      end
      n_p
    rescue StopParsing
      @bufcur = pos
      @linenum = l
      @charnum = n
      @linepos = o
      return nil
    end

    def parse_term(rule)
      pos = @bufcur
      l = @linenum
      n = @charnum
      o = @linepos
      if match_character("&")
        t = "&".ord
      elsif match_character("!")
        t = "!".ord
      else
        t = 0
      end
      if t
        match_spaces
      end

      n_p = parse_primary(rule)
      if !n_p
        raise StopParsing
      end
      if match_character("*")
        match_spaces
        n_q = Packcr::Node::QuantityNode.new
        n_q.min = 0
        n_q.max = -1
        n_q.expr = n_p
      elsif match_character("+")
        match_spaces
        n_q = Packcr::Node::QuantityNode.new
        n_q.min = 1
        n_q.max = -1
        n_q.expr = n_p
      elsif match_character("?")
        match_spaces
        n_q = Packcr::Node::QuantityNode.new
        n_q.min = 0
        n_q.max = 1
        n_q.expr = n_p
      else
        n_q = n_p
      end

      case t
      when "&".ord
        n_r = Packcr::Node::PredicateNode.new
        n_r.neg = false
        n_r.expr = n_q
      when "!".ord
        n_r = Packcr::Node::PredicateNode.new
        n_r.neg = true
        n_r.expr = n_q
      else
        n_r = n_q
      end

      if match_character("~")
        match_spaces
        pos2 = @bufcur
        l2 = @linenum
        m = column_number
        if match_code_block
          q = @bufcur
          text = @buffer.to_s
          text = text, [pos2 + 1, q - pos2 - 2]
          match_spaces
          n_t = Packcr::Node::ErrorNode.new
          n_t.expr = n_r
          n_t.code = Packcr::CodeBlock.new(text, Packcr.find_trailing_blanks(text), l2, m);
          n_t.index = rcodes.length
          @codes.push(n_t)
        else
          raise StopParsing
        end
      else
        n_t = n_r
      end
      n_t
    rescue StopParsing
      @bufcur = pos
      @linenum = l
      @charnum = n
      @linepos = o
      return nil
    end

    def parse_sequence(rule)
      pos = @bufcur
      l = @linenum
      n = @charnum
      o = @linepos
      n_t = parse_term(rule)
      if !n_t
        raise StopParsing
      end
      n_u = parse_term(rule);
      if n_u
        n_s = Packcr::Node::SequenceNode.new
        n_s.add_node(n_t)
        n_s.add_node(n_u)
        while (n_t = parse_term(rule))
          n_s.add_node(n_t)
        end
      else
        n_s = n_t
      end
      n_s
    rescue StopParsing
      @bufcur = pos
      @linenum = l
      @charnum = n
      @linepos = o
      return nil
    end

    def parse_expression(rule)
      pos = @bufcur
      l = @linenum
      n = @charnum
      o = @linepos
      n_s = parse_sequence(rule)
      if !n_s
        raise StopParsing
      end
      q = @bufcur
      if (match_character("/".ord))
        @bufcur = q
        n_e = Packcr::Node::AlternateNode.new
        n_e.add_node(n_s)
        while match_character("/".ord)
          match_spaces
          n_s = parse_sequence(rule)
          if !n_s
            raise StopParsing
          end
          n_e.add_node(n_s)
        end
      else
        n_e = n_s
      end
      return n_e
    rescue StopParsing
      @bufcur = pos
      @linenum = l
      @charnum = n
      @linepos = o
      return nil
    end

    def parse_rule
      pos = @bufcur
      l = @linenum
      m = column_number
      n = @charnum
      o = @linepos
      if !match_identifier
        raise StopParsing
      end

      q = @bufcur
      match_spaces
      if !match_string("<-")
        raise StopParsing
      end
      match_spaces

      n_r = Packcr::Node::RuleNode.new
      expr = parse_expression(n_r)
      n_r.expr = expr
      if !expr
        raise StopParsing
      end
      unless q >= pos
        raise "Internal error"
      end
      name = @buffer.to_s
      name = name[pos, q - pos]
      n_r.name = name
      n_r.line = l
      n_r.col = m
      n_r
    rescue StopParsing
      @bufcur = pos
      @linenum = l
      @charnum = n
      @linepos = o
      return nil
    end

    def parse
      match_spaces

      b = true
      while true
        if eof? || match_footer_start
          break
        end
        if (
            parse_directive_include("%earlysource", @esource) ||
            parse_directive_include("%earlycommon", @esource, @eheader) ||
            parse_directive_include("%source", @source) ||
            parse_directive_include("%header", @header) ||
            parse_directive_include("%common", @source, @header) ||
            parse_directive_string("%value", "@value_type", must_not_be_empty: true, must_not_be_void: true) ||
            parse_directive_string("%auxil", "@auxil_type", must_not_be_empty: true, must_not_be_void: true) ||
            parse_directive_string("%prefix", "@prefix", must_not_be_empty: true, must_be_identifier: true)
          )
          b = true
        elsif match_character("%")
          l = @linenum
          m = column_number
          warn "#{@iname}:#{l + 1}:#{m + 1}: Invalid directive"
          @errnum += 1
          match_identifier
          match_spaces
          b = true
        else
          l = @linenum
          m = column_number
          n = @charnum
          o = @linepos
          node = parse_rule
          if node == nil
            if b
              warn "#{@iname}:#{l + 1}:#{m + 1}: Illegal rule syntax"
              @errnum += 1
              b = false
            end
            @linenum = l
            @charnum = n
            @linepos = o
            if !match_identifier && !match_spaces
              match_character_any
            end
          else
            @rules.push(node)
            b = true
          end
        end
        commit_buffer
      end

      commit_buffer

      make_rulehash
      @rules.each do |rule|
        link_references(rule.expr)
      end
      @rules[1..-1]&.each do |rule|
        if rule.ref == 0
          warn "#{@iname}:#{rule.line + 1}:#{rule.col + 1}: Never used rule '#{rule.name}'\n"
          @errnum += 1
        elsif rule.ref < 0 # impossible?
          warn "#{@iname}:#{rule.line + 1}:#{rule.col + 1}: Multiple definition of rule '#{rule.name}'\n"
          @errnum += 1
        end
      end

      @rules.each do |rule|
        verify_variables(rule.expr)
        verify_captures(rule.expr)
      end

      if @debug
        @rules.each(&:debug_dump)
        dump_options
      end

      @errnum.zero?
    end

    def generate
      File.open(@hname, "wt") do |hio|
        hstream = ::Packcr::Stream.new(hio, @hname, @lines ? 0 : nil)

        hstream.write "/* A packrat parser generated by PackCR %s */\n\n" %  ::Packcr::VERSION

        @eheader.each do |code|
          hstream.write_code_block(code, 0, @iname)
        end
        hstream.write "\n" if !@eheader.empty?

        hstream.write(<<~EOS)
          #ifndef PCC_INCLUDED_#{@hid}
          #define PCC_INCLUDED_#{@hid}

        EOS

        @header.each do |code|
          hstream.write_code_block(code, 0, @iname)
        end

        hstream.write(<<~EOS)
          #ifdef __cplusplus
          extern "C" {
          #endif

          typedef struct #{prefix}_context_tag #{prefix}_context_t;

          #{prefix}_context_t *#{prefix}_create(#{auxil_def}auxil);
          int #{prefix}_parse(#{prefix}_context_t *ctx, #{value_def}*ret);
          void #{prefix}_destroy(#{prefix}_context_t *ctx);

          #ifdef __cplusplus
          }
          #endif

          #endif /* !PCC_INCLUDED_#{@hid} */
        EOS
      end

      File.open(@sname, "wt") do |sio|
        sstream = ::Packcr::Stream.new(sio, @sname, @lines ? 0 : nil)
        sstream.write "/* A packrat parser generated by PackCR %s */\n\n" % ::Packcr::VERSION

        @esource.each do |code|
          sstream.write_code_block(code, 0, @iname)
        end
        sstream.write "\n" if !@esource.empty?

        sstream.write Packcr.template("context/esource.c.erb", binding)

        @source.each do |code|
          sstream.write_code_block(code, 0, @iname)
        end

        sstream.write Packcr.template("context/source.c.erb", binding)

        @rules.each do |rule|
          rule.codes.each do |code|
            sstream.write Packcr.template("context/source_rule_code1.c.erb", binding)
            sstream.write_code_block(code.code, 4, @iname)
            sstream.write Packcr.template("context/source_rule_code2.c.erb", binding)
          end
        end

        sstream.write Packcr.template("context/source_rule.c.erb", binding)

        eol?
        if !eof?
          sstream.write("\n")
        end
        commit_buffer
        if @lines && !eof?
          sstream.write_line_directive(@iname, @linenum)
        end
        while refill_buffer > 0
          write_buffer(sstream)
          commit_buffer
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
end