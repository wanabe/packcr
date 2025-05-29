class Packcr
  class Node
    class SequenceNode
      def get_code(gen, onfail, indent, unwrap, oncut)
        case gen.lang
        when :c
          erbout = +""
          if @cut && oncut
            onfail = oncut
            oncut = nil
          end
          nodes.each_with_index do |expr, i|
            erbout << "#{gen.generate_code(expr, onfail, 0, false, oncut: oncut)}".freeze
            next unless expr.reachability == Packcr::CODE_REACH__ALWAYS_FAIL

            if i + 1 < nodes.length
              erbout << "/* unreachable codes omitted */\n".freeze
            end
            break
          end
          erbout
        when :rb
          erbout = +""
          if @cut && oncut
            onfail = oncut
            oncut = nil
          end
          nodes.each_with_index do |expr, i|
            erbout << "#{gen.generate_code(expr, onfail, 0, false, oncut: oncut)}".freeze
            next unless expr.reachability == Packcr::CODE_REACH__ALWAYS_FAIL

            if i + 1 < nodes.length
              erbout << "# unreachable codes omitted\n".freeze
            end
            break
          end
          erbout
        when :rs
          erbout = +""
          if @cut && oncut
            onfail = oncut
            oncut = nil
          end
          nodes.each_with_index do |expr, i|
            erbout << "#{gen.generate_code(expr, onfail, 0, false, oncut: oncut)}".freeze
            next unless expr.reachability == Packcr::CODE_REACH__ALWAYS_FAIL

            if i < nodes.length - 1
              erbout << "/* unreachable codes omitted */\n".freeze
            end
            break
          end
          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end
    end
  end
end
