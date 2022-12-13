
class Packcr
  class Generator
    def initialize(stream, rule, ascii)
      @stream = stream
      @rule = rule
      @label = 0
      @ascii = !!ascii
    end

    def next_label
      @label += 1
    end

    def generate_matching_string_code(value, onfail, indent, bare)
      n = value&.length || 0

      if n > 0
        if n > 1
          @stream.write Packcr.template("generator/matching_string_many.c.erb", binding, indent: indent)
          return Packcr::CODE_REACH__BOTH
        else
          @stream.write Packcr.template("generator/matching_string_one.c.erb", binding, indent: indent)
          return Packcr::CODE_REACH__BOTH
        end
      else
        # no code to generate
        return Packcr::CODE_REACH__ALWAYS_SUCCEED
      end
    end

    def generate_matching_charclass_code(charclass, onfail, indent, bare)
      if !@ascii
        raise "unexpected calling #generate_matching_charclass_code on no-ascii mode"
      end

      if charclass
        n = charclass.length
        a = charclass[0] == "^"
        if a
          n -= 1
          charclass = charclass[1..-1]
        end
        if n > 0
          if n > 1
            generate_block(indent, bare) do |indent|
              if !a && charclass =~ /\A[^\\]-.\z/
                @stream.write Packcr.template("generator/matching_charclass_range_one.c.erb", binding, indent: indent)
              else
                @stream.write Packcr.template("generator/matching_charclass.c.erb", binding, indent: indent)
              end
            end
            return Packcr::CODE_REACH__BOTH
          elsif a
            @stream.write Packcr.template("generator/matching_charclass_neg_one.c.erb", binding, indent: indent)
            return Packcr::CODE_REACH__BOTH
          else
            @stream.write Packcr.template("generator/matching_charclass_one.c.erb", binding, indent: indent)
            return Packcr::CODE_REACH__BOTH
          end
        else
          @stream.write " " * indent
          @stream.write "goto L#{"%04d" % onfail};\n"
          return Packcr::CODE_REACH__ALWAYS_FAIL
        end
      else
        @stream.write(<<~EOS.gsub(/^/, " " * indent))
          if (pcc_refill_buffer(ctx, 1) < 1) goto L#{"%04d" % onfail};
          ctx->cur++;
        EOS
        return Packcr::CODE_REACH__BOTH
      end
    end

    def generate_matching_utf8_charclass_code(charclass, onfail, indent, bare)
      if charclass && charclass.encoding != Encoding::UTF_8
        charclass = charclass.dup.force_encoding(Encoding::UTF_8)
      end
      n = charclass&.length || 0
      if charclass.nil? || n > 0
        a = charclass && charclass[0] == '^'
        i = a ? 1 : 0
        generate_block(indent, bare) do |indent|
          @stream.write Packcr.template("generator/matching_charclass_utf8.c.erb", binding, indent: indent)
        end
        return Packcr::CODE_REACH__BOTH
      else
        @stream.write " " * indent
        @stream.write "goto L#{"%04d" % onfail};\n"
        return Packcr::CODE_REACH__ALWAYS_FAIL
      end
    end

    def generate_quantifying_code(expr, min, max, onfail, indent, bare)
      if max > 1 || max < 0
        generate_block(indent, bare) do |indent|
          if min > 0
            @stream.write " " * indent
            @stream.write "const size_t p0 = ctx->cur;\n"
            @stream.write " " * indent
            @stream.write "const size_t n0 = chunk->thunks.len;\n"
          end
          @stream.write " " * indent
          @stream.write "int i;\n"
          @stream.write " " * indent

          if max < 0
            @stream.write "for (i = 0;; i++) {\n"
          else
            @stream.write "for (i = 0; i < #{max}; i++) {\n"
          end
          @stream.write " " * (indent + 4)
          @stream.write "const size_t p = ctx->cur;\n"
          @stream.write " " * (indent + 4)
          @stream.write "const size_t n = chunk->thunks.len;\n"

          l = next_label
          r = generate_code(expr, l, indent + 4, false)
          @stream.write " " * (indent + 4)
          @stream.write "if (ctx->cur == p) break;\n"
          if r !=Packcr::CODE_REACH__ALWAYS_SUCCEED
            @stream.write " " * (indent + 4)
            @stream.write "continue;\n"
            @stream.write " " * indent
            @stream.write "L#{"%04d" % l}:;\n"
            @stream.write " " * (indent + 4)
            @stream.write "ctx->cur = p;\n"
            @stream.write " " * (indent + 4)
            @stream.write "pcc_thunk_array__revert(ctx->auxil, &chunk->thunks, n);\n"
            @stream.write " " * (indent + 4)
            @stream.write "break;\n"
          end

          @stream.write " " * indent
          @stream.write "}\n"

          if min > 0
            @stream.write " " * indent
            @stream.write "if (i < #{min}) {\n"
            @stream.write " " * (indent + 4)
            @stream.write "ctx->cur = p0;\n"
            @stream.write " " * (indent + 4)
            @stream.write "pcc_thunk_array__revert(ctx->auxil, &chunk->thunks, n0);\n"
            @stream.write " " * (indent + 4)
            @stream.write "goto L#{"%04d" % onfail};\n"
            @stream.write " " * indent
            @stream.write "}\n"
          end
          if min > 0
            return r ==Packcr::CODE_REACH__ALWAYS_FAIL ? Packcr::CODE_REACH__ALWAYS_FAIL : Packcr::CODE_REACH__BOTH
          else
            return Packcr::CODE_REACH__ALWAYS_SUCCEED
          end
        end
      elsif max == 1
        if min > 0
          return generate_code(expr, onfail, indent, bare)
        else
          generate_block(indent, bare) do |indent|
            @stream.write " " * indent
            @stream.write "const size_t p = ctx->cur;\n"
            @stream.write " " * indent
            @stream.write "const size_t n = chunk->thunks.len;\n"
            l = next_label
            if generate_code(expr, l, indent, false) != Packcr::CODE_REACH__ALWAYS_SUCCEED
              m = next_label
              @stream.write " " * indent
              @stream.write "goto L#{"%04d" % m};\n"
              if indent > 4
                @stream.write " " * (indent - 4)
              end
              @stream.write "L#{"%04d" % l}:;\n"
              @stream.write " " * indent
              @stream.write "ctx->cur = p;\n"
              @stream.write " " * indent
              @stream.write "pcc_thunk_array__revert(ctx->auxil, &chunk->thunks, n);\n"
              if indent > 4
                @stream.write " " * (indent - 4)
              end
              @stream.write "L#{"%04d" % m}:;\n"
            end
          end
          return Packcr::CODE_REACH__ALWAYS_SUCCEED
        end
      else
        # no code to generate
        return Packcr::CODE_REACH__ALWAYS_SUCCEED
      end
    end

    def generate_predicating_code(expr, neg, onfail, indent, bare)
      generate_block(indent, bare) do |indent|
        @stream.write " " * indent
        @stream.write "const size_t p = ctx->cur;\n"

        if neg
          l = next_label
          r = generate_code(expr, l, indent, false)

          if r != Packcr::CODE_REACH__ALWAYS_FAIL
            @stream.write " " * indent
            @stream.write "ctx->cur = p;\n"
            @stream.write " " * indent
            @stream.write "goto L#{"%04d" % onfail};\n"
          end
          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            if indent > 4
              @stream.write " " * (indent - 4)
            end
            @stream.write "L#{"%04d" % l}:;\n"
            @stream.write " " * indent
            @stream.write "ctx->cur = p;\n"
          end

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
          if r != Packcr::CODE_REACH__ALWAYS_FAIL
            @stream.write " " * indent
            @stream.write "ctx->cur = p;\n"
          end
          if r == Packcr::CODE_REACH__BOTH
            @stream.write " " * indent
            @stream.write "goto L#{"%04d" % m};\n"
          end
          if r != Packcr::CODE_REACH__ALWAYS_SUCCEED
            if indent > 4
              @stream.write " " * (indent - 4)
            end
            @stream.write "L#{"%04d" % l}:;\n"
            @stream.write " " * indent
            @stream.write "ctx->cur = p;\n"
            @stream.write " " * indent
            @stream.write "goto L#{"%04d" % onfail};\n"
          end
          if r == Packcr::CODE_REACH__BOTH
            if indent > 4
              @stream.write " " * (indent - 4)
            end
            @stream.write "L#{"%04d" % m}:;\n"
          end
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
        @stream.write " " * indent
        @stream.write "const size_t n = chunk->capts.buf[#{index}].range.end - chunk->capts.buf[#{index}].range.start;\n"
        @stream.write " " * indent
        @stream.write "if (pcc_refill_buffer(ctx, n) < n) goto L#{"%04d" % onfail};\n"
        @stream.write " " * indent
        @stream.write "if (n > 0) {\n"
        @stream.write " " * (indent + 4)
        @stream.write "const char *const p = ctx->buffer.buf + ctx->cur;\n"
        @stream.write " " * (indent + 4)
        @stream.write "const char *const q = ctx->buffer.buf + chunk->capts.buf[#{index}].range.start;\n"
        @stream.write " " * (indent + 4)
        @stream.write "size_t i;\n"
        @stream.write " " * (indent + 4)
        @stream.write "for (i = 0; i < n; i++) {\n"
        @stream.write " " * (indent + 8)
        @stream.write "if (p[i] != q[i]) goto L#{"%04d" % onfail};\n"
        @stream.write " " * (indent + 4)
        @stream.write "}\n"
        @stream.write " " * (indent + 4)
        @stream.write "ctx->cur += n;\n"
        @stream.write " " * indent
        @stream.write "}\n"
      end
      return Packcr::CODE_REACH__BOTH
    end

    def generate_thunking_action_code(index, vars, capts, error, onfail, indent, bare)
      generate_block(indent, bare) do |indent|
        if error
          @stream.write " " * indent
          @stream.write "pcc_value_t null;\n"
        end
        @stream.write " " * indent
        @stream.write "pcc_thunk_t *const thunk = pcc_thunk__create_leaf(ctx->auxil, pcc_action_#{@rule.name}_#{index}, #{@rule.vars.length}, #{@rule.capts.length});\n"

        vars.each do |var|
          @stream.write " " * indent
          @stream.write "thunk->data.leaf.values.buf[#{var.index}] = &(chunk->values.buf[#{var.index}]);\n"
        end
        capts.each do |capt|
          @stream.write " " * indent
          @stream.write "thunk->data.leaf.capts.buf[#{capt.index}] = &(chunk->capts.buf[#{capt.index}]);\n"
        end
        @stream.write " " * indent
        @stream.write "thunk->data.leaf.capt0.range.start = chunk->pos;\n"
        @stream.write " " * indent
        @stream.write "thunk->data.leaf.capt0.range.end = ctx->cur;\n"

        if error
          @stream.write " " * indent
          @stream.write "memset(&null, 0, sizeof(pcc_value_t /* in case */\n"
          @stream.write " " * indent
          @stream.write "thunk->data.leaf.action(ctx, thunk, &null);\n"
          @stream.write " " * indent
          @stream.write "pcc_thunk__destroy(ctx->auxil, thunk);\n"
        else
          @stream.write " " * indent
          @stream.write "pcc_thunk_array__add(ctx->auxil, &chunk->thunks, thunk);\n"
        end
      end
      return Packcr::CODE_REACH__ALWAYS_SUCCEED
    end

    def generate_thunking_error_code(expr, index, vars, capts, onfail, indent, bare)
      l = next_label
      m = next_label
      generate_block(indent, bare) do |indent|
        r = generate_code(expr, l, indent, true)
        @stream.write " " * indent
        @stream.write "goto L#{"%04d" % m};\n"
        if indent > 4
          @stream.write " " * (indent - 4)
        end
        @stream.write "L#{"%04d" % l}:;\n"
        generate_thunking_action_code(index, vars, capts, true, l, indent, true)
        @stream.write " " * indent
        @stream.write "goto L#{"%04d" % onfail};\n"
        if indent > 4
          @stream.write " " * (indent - 4)
        end
        @stream.write "L%#{"04d" % m}:;\n"
      end
      return r
    end

    def generate_code(node, onfail, indent, bare)
      if !node
        raise "Internal error"
      end
      case node
      when ::Packcr::Node::RuleNode
        raise "Internal error"
      when ::Packcr::Node::ReferenceNode
        if node.index != nil
          @stream.write " " * indent
          @stream.write "if (!pcc_apply_rule(ctx, pcc_evaluate_rule_#{node.name}, &chunk->thunks, &(chunk->values.buf[#{node.index}]))) goto L#{"%04d" % onfail};\n"
        else
          @stream.write " " * indent
          @stream.write "if (!pcc_apply_rule(ctx, pcc_evaluate_rule_#{node.name}, &chunk->thunks, NULL)) goto L#{"%04d" % onfail};\n"
        end
        return Packcr::CODE_REACH__BOTH
      when ::Packcr::Node::StringNode
        return generate_matching_string_code(node.value, onfail, indent, bare)
      when ::Packcr::Node::CharclassNode
        if @ascii
          return generate_matching_charclass_code(node.value, onfail, indent, bare)
        else
          return generate_matching_utf8_charclass_code(node.value, onfail, indent, bare)
        end
      when ::Packcr::Node::QuantityNode
        return generate_quantifying_code(node.expr, node.min, node.max, onfail, indent, bare)
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
