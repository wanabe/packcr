class Packcr
  class Node
    class AlternateNode < Packcr::Node
      def initialize
        super
        self.nodes = []
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Alternate(max:#{max}, len:#{nodes.length}) {\n"
        nodes.each do |child_node|
          child_node.debug_dump(indent + 2)
        end
        $stdout.print "#{" " * indent}}\n"
      end

      def max
        m = 1
        m <<= 1 while m < @nodes.length
        m
      end

      def generate_code(gen, onfail, indent, bare)
        b = false
        m = gen.next_label

        gen.generate_block(indent, bare) do |indent|
          gen.write " " * indent
          gen.write "const size_t p = ctx->cur;\n"
          gen.write " " * indent
          gen.write "const size_t n = chunk->thunks.len;\n"

          nodes.each_with_index do |expr, i|
            c = i + 1 < nodes.length
            l = gen.next_label
            case gen.generate_code(expr, l, indent, false)
            when Packcr::CODE_REACH__ALWAYS_SUCCEED
              if c
                gen.write " " * indent
                gen.write "/* unreachable codes omitted */\n"
              end
              if b
                if indent > 4
                  gen.write " " * (indent - 4)
                end
                gen.write "L#{"%04d" % m}:;\n"
              end
              return Packcr::CODE_REACH__ALWAYS_SUCCEED
            when Packcr::CODE_REACH__ALWAYS_FAIL
            else
              b = true
              gen.write " " * indent
              gen.write "goto L#{"%04d" % m};\n"
            end

            if indent > 4
              gen.write " " * (indent - 4)
            end
            gen.write "L#{"%04d" % l}:;\n"
            gen.write " " * indent
            gen.write "ctx->cur = p;\n"
            gen.write " " * indent
            gen.write "pcc_thunk_array__revert(ctx->auxil, &chunk->thunks, n);\n"
            if !c
              gen.write " " * indent
              gen.write "goto L#{"%04d" % onfail};\n"
            end
          end
          if b
            if indent > 4
              gen.write " " * (indent - 4)
            end
            gen.write "L#{"%04d" % m}:;\n"
          end

          b ? Packcr::CODE_REACH__BOTH : Packcr::CODE_REACH__ALWAYS_FAIL
        end
      end
    end
  end
end
