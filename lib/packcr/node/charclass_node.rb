class Packcr
  class Node
    class CharclassNode < Packcr::Node
      def initialize
        super
        self.value = nil
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Charclass(value:'"
        Packcr.dump_escaped_string(value)
        $stdout.print "')\n"
      end

      def generate_code(gen, onfail, indent, bare)
        if gen.ascii
          return generate_ascii_code(gen, onfail, indent, bare)
        else
          return generate_utf8_charclass_code(gen, onfail, indent, bare)
        end
      end

      def generate_utf8_charclass_code(gen, onfail, indent, bare)
        charclass = self.value
        if charclass && charclass.encoding != Encoding::UTF_8
          charclass = charclass.dup.force_encoding(Encoding::UTF_8)
        end
        n = charclass&.length || 0
        if charclass.nil? || n > 0
          a = charclass && charclass[0] == '^'
          i = a ? 1 : 0
          gen.generate_block(indent, bare) do |indent|
            gen.write Packcr.template("node/charclass_utf8.c.erb", binding, indent: indent)
          end
          return Packcr::CODE_REACH__BOTH
        else
          gen.write " " * indent
          gen.write "goto L#{"%04d" % onfail};\n"
          return Packcr::CODE_REACH__ALWAYS_FAIL
        end
      end

      def generate_ascii_code(gen, onfail, indent, bare)
        charclass = self.value
        if charclass
          n = charclass.length
          a = charclass[0] == "^"
          if a
            n -= 1
            charclass = charclass[1..-1]
          end
          if n > 0
            if n > 1
              gen.generate_block(indent, bare) do |indent|
                if !a && charclass =~ /\A[^\\]-.\z/
                  gen.write Packcr.template("node/charclass_range_one.c.erb", binding, indent: indent)
                else
                  gen.write Packcr.template("node/charclass.c.erb", binding, indent: indent)
                end
              end
              return Packcr::CODE_REACH__BOTH
            elsif a
              gen.write Packcr.template("node/charclass_neg_one.c.erb", binding, indent: indent)
              return Packcr::CODE_REACH__BOTH
            else
              gen.write Packcr.template("node/charclass_one.c.erb", binding, indent: indent)
              return Packcr::CODE_REACH__BOTH
            end
          else
            gen.write " " * indent
            gen.write "goto L#{"%04d" % onfail};\n"
            return Packcr::CODE_REACH__ALWAYS_FAIL
          end
        else
          gen.write(<<~EOS.gsub(/^/, " " * indent))
            if (pcc_refill_buffer(ctx, 1) < 1) goto L#{"%04d" % onfail};
            ctx->cur++;
          EOS
          return Packcr::CODE_REACH__BOTH
        end
      end
    end
  end
end