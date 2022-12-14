class Packcr
  class Node
    class ErrorNode < Packcr::Node
      def initialize
        super
        self.expr = nil
        self.code = Packcr::CodeBlock.new
        self.index = nil
        self.vars = []
        self.capts = []
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Error(index:"
        Packcr.dump_integer_value(index)
        $stdout.print ", code:{"
        Packcr.dump_escaped_string(code.text)
        $stdout.print "}, vars:\n"
        vars.each do |ref|
          $stdout.print "#{" " * (indent + 2)}'#{ref.var}'\n"
        end
        capts.each do |capt|
          $stdout.print "#{" " * (indent + 2)}$#{capt.index + 1}\n"
        end
        $stdout.print "#{" " * indent}) {\n"
        expr.debug_dump(indent + 2)
        $stdout.print "#{" " * indent}}\n"
      end

      def generate_code(gen, onfail, indent, bare)
        l = gen.next_label
        m = gen.next_label
        gen.generate_block(indent, bare) do |indent|
          r = gen.generate_code(expr, l, indent, true)
          gen.write Packcr.template("node/error.c.erb", binding, indent: indent - 4)
          return r
        end
      end
    end
  end
end
