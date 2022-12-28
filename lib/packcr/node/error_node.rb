class Packcr
  class Node
    class ErrorNode < Packcr::Node
      attr_accessor :expr, :code, :index, :vars, :capts

      def initialize
        super
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
        r, code = gen.generate_code_str(expr, l, 4, true)
        gen.write Packcr.template("node/error.#{gen.lang}.erb", binding, indent: indent, unwrap: bare)
        return r
      end

      def verify_variables(vars)
        @vars = vars
        expr.verify_variables(vars)
      end

      def verify_captures(ctx, capts)
        @capts = capts
        expr.verify_captures(ctx, capts)
      end

      def link_references(ctx)
        expr.link_references(ctx)
      end
    end
  end
end
