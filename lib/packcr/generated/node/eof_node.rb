class Packcr
  class Node
    class EofNode
      def get_code(gen, onfail, indent, unwrap, oncut)
        case gen.lang
        when :c
          erbout = +""
          erbout << "if (packcr_refill_buffer(ctx, 1) >= 1) goto L#{format("%04d", onfail)};\n".freeze

          erbout
        when :rb
          erbout = +""
          erbout << "if refill_buffer(1) >= 1\n  throw(#{onfail})\nend\n".freeze

          erbout
        when :rs
          erbout = +""
          erbout << "/* lib/packcr/templates/node/eof.rs.erb */\n\n".freeze

          erbout
        else
          raise "unknown lang #{gen.lang}"
        end
      end
    end
  end
end
