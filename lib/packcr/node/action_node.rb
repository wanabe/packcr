class Packcr
  class Node
    class ActionNode < Packcr::Node
      attr_accessor :code, :index, :vars, :capts

      def initialize(code = nil)
        super()
        @code = code
        self.vars = []
        self.capts = []
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Action(index:"
        Packcr.dump_integer_value(index)
        $stdout.print ", code:{"
        Packcr.dump_escaped_string(code.text)
        $stdout.print "}, vars:"

        vars = self.vars
        capts = self.capts
        if vars.length + capts.length > 0
          $stdout.print "\n"
          vars.each do |ref|
            $stdout.print "#{" " * (indent + 2)}'#{ref.var}'\n"
          end
          capts.each do |capt|
            $stdout.print "#{" " * (indent + 2)}$#{capt.index + 1}\n"
          end
          $stdout.print "#{" " * indent})\n"
        else
          $stdout.print "none)\n"
        end
      end

      def generate_code(gen, onfail, indent, bare)
        gen.write Packcr.template("node/action.#{gen.lang}.erb", binding, indent: indent, unwrap: bare)
        return Packcr::CODE_REACH__ALWAYS_SUCCEED
      end

      def verify_variables(vars)
        @vars = vars
      end

      def verify_captures(ctx, capts)
        @capts = capts
      end

      def link_references(ctx)
      end

      def setup_rule(rule)
        @index = rule.codes.length
        rule.codes.push(self)
      end
    end
  end
end
