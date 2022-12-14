
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
           ::Packcr::Node::PredicateNode,
           ::Packcr::Node::SequenceNode,
           ::Packcr::Node::AlternateNode,
           ::Packcr::Node::RuleNode
        return node.generate_code(self, onfail, indent, bare)
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
