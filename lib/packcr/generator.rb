
class Packcr
  class Generator
    attr_reader :ascii

    def initialize(stream, rule, ascii)
      @stream = stream
      @rule = rule
      @label = 0
      @ascii = !!ascii
    end

    def next_label
      @label += 1
    end

    def generate_predicating_code(expr, neg, onfail, indent, bare)
      generate_block(indent, bare) do |indent|
        @stream.write(<<~EOS.gsub(/^/, " " * indent))
          const size_t p = ctx->cur;
        EOS

        if neg
          l = next_label
          r = generate_code(expr, l, indent, false)

          @stream.write Packcr.template("generator/predicating_neg.c.erb", binding, indent: indent)

          case r
          when Packcr::CODE_REACH__ALWAYS_SUCCEED
            r = Packcr::CODE_REACH__ALWAYS_FAIL
          when Packcr::CODE_REACH__ALWAYS_FAIL
            r = Packcr::CODE_REACH__ALWAYS_SUCCEED
          end
        else
          l = next_label
          m = next_label
          r = generate_code(expr, l, indent, false)
          @stream.write Packcr.template("generator/predicating.c.erb", binding, indent: indent)
        end
        return r
      end
    end

    def generate_sequential_code(nodes, onfail, indent, bare)
      b = false
      nodes.each_with_index do |expr, i|
        case generate_code(expr, onfail, indent, false)
        when Packcr::CODE_REACH__ALWAYS_FAIL
          if i + 1 < rnodes.length
            @stream.write " " * indent
            @stream.write "/* unreachable codes omitted */\n"
          end
          return Packcr::CODE_REACH__ALWAYS_FAIL
        when Packcr::CODE_REACH__ALWAYS_SUCCEED
        else
          b = true
        end
      end
      return b ? Packcr::CODE_REACH__BOTH : Packcr::CODE_REACH__ALWAYS_SUCCEED
    end

    def generate_alternative_code(nodes, onfail, indent, bare)
      b = false
      m = next_label

      generate_block(indent, bare) do |indent|
        @stream.write " " * indent
        @stream.write "const size_t p = ctx->cur;\n"
        @stream.write " " * indent
        @stream.write "const size_t n = chunk->thunks.len;\n"

        nodes.each_with_index do |expr, i|
          c = i + 1 < nodes.length
          l = next_label
          case generate_code(expr, l, indent, false)
          when Packcr::CODE_REACH__ALWAYS_SUCCEED
            if c
              @stream.write " " * indent
              @stream.write "/* unreachable codes omitted */\n"
            end
            if b
              if indent > 4
                @stream.write " " * (indent - 4)
              end
              @stream.write "L#{"%04d" % m}:;\n"
            end
            return Packcr::CODE_REACH__ALWAYS_SUCCEED
          when Packcr::CODE_REACH__ALWAYS_FAIL
          else
            b = true
            @stream.write " " * indent
            @stream.write "goto L#{"%04d" % m};\n"
          end

          if indent > 4
            @stream.write " " * (indent - 4)
          end
          @stream.write "L#{"%04d" % l}:;\n"
          @stream.write " " * indent
          @stream.write "ctx->cur = p;\n"
          @stream.write " " * indent
          @stream.write "pcc_thunk_array__revert(ctx->auxil, &chunk->thunks, n);\n"
          if !c
            @stream.write " " * indent
            @stream.write "goto L#{"%04d" % onfail};\n"
          end
        end
        if b
          if indent > 4
            @stream.write " " * (indent - 4)
          end
          @stream.write "L#{"%04d" % m}:;\n"
        end

        b ? Packcr::CODE_REACH__BOTH : Packcr::CODE_REACH__ALWAYS_FAIL
      end
    end

    def generate_capturing_code(expr, index, onfail, indent, bare)
      generate_block(indent, bare) do |indent|
        @stream.write " " * indent
        @stream.write "const size_t p = ctx->cur;\n"
        @stream.write " " * indent
        @stream.write "size_t q;\n"
        r = generate_code(expr, onfail, indent, false)
        @stream.write " " * indent
        @stream.write "q = ctx->cur;\n"
        @stream.write " " * indent
        @stream.write "chunk->capts.buf[#{index}].range.start = p;\n"
        @stream.write " " * indent
        @stream.write "chunk->capts.buf[#{index}].range.end = q;\n"
        return r
      end
    end

    def generate_expanding_code(index, onfail, indent, bare)
      generate_block(indent, bare) do |indent|
        @stream.write Packcr.template("generator/expanding.c.erb", binding, indent: indent)
      end
      return Packcr::CODE_REACH__BOTH
    end

    def generate_thunking_action_code(index, vars, capts, error, onfail, indent, bare)
      generate_block(indent, bare) do |indent|
        @stream.write Packcr.template("generator/thunking_action.c.erb", binding, indent: indent)
      end
      return Packcr::CODE_REACH__ALWAYS_SUCCEED
    end

    def generate_thunking_error_code(expr, index, vars, capts, onfail, indent, bare)
      l = next_label
      m = next_label
      generate_block(indent, bare) do |indent|
        r = generate_code(expr, l, indent, true)
        @stream.write Packcr.template("generator/thunking_error.c.erb", binding, indent: indent)
        return r
      end
    end

    def generate_code(node, onfail, indent, bare)
      if !node
        raise "Internal error"
      end
      case node
      when ::Packcr::Node::ReferenceNode,
           ::Packcr::Node::StringNode,
           ::Packcr::Node::CharclassNode,
           ::Packcr::Node::QuantityNode,
           ::Packcr::Node::RuleNode
        return node.generate_code(self, onfail, indent, bare)
      when ::Packcr::Node::PredicateNode
        return generate_predicating_code(node.expr, node.neg, onfail, indent, bare)
      when ::Packcr::Node::SequenceNode
        return generate_sequential_code(node.nodes, onfail, indent, bare)
      when ::Packcr::Node::AlternateNode
        return generate_alternative_code(node.nodes, onfail, indent, bare)
      when ::Packcr::Node::CaptureNode
        return generate_capturing_code(node.expr, node.index, onfail, indent, bare)
      when ::Packcr::Node::ExpandNode
        return generate_expanding_code(node.index, onfail, indent, bare)
      when ::Packcr::Node::ActionNode
        return generate_thunking_action_code(node.index, node.vars, node.capts, false, onfail, indent, bare)
      when ::Packcr::Node::ErrorNode
        return generate_thunking_error_code(node.expr, node.index, node.vars, node.capts, onfail, indent, bare)
      else
        raise "Internal error"
      end
    end

    def write(str)
      @stream.write(str)
    end

    def generate_block(indent, bare)
      if !bare
        @stream.write " " * indent
        @stream.write "{\n"
      end

      yield indent + 4
    ensure
      if !bare
        @stream.write " " * indent
        @stream.write "}\n"
      end
    end
  end
end
