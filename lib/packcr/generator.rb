
class Packcr
  class Generator
    attr_reader :ascii, :rule

    def initialize(stream, rule, ascii)
      @stream = stream
      @rule = rule
      @label = 0
      @ascii = !!ascii
    end

    def next_label
      @label += 1
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
           ::Packcr::Node::CaptureNode,
           ::Packcr::Node::ExpandNode,
           ::Packcr::Node::ActionNode,
           ::Packcr::Node::RuleNode
        return node.generate_code(self, onfail, indent, bare)
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
