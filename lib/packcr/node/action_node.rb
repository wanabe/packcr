class Packcr
  class Node
    class ActionNode < Packcr::Node
      def initialize
        super
        self.code = Packcr::CodeBlock.new
        self.index = nil
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
    end
  end
end
