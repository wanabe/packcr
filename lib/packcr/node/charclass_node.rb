class Packcr
  class Node
    class CharclassNode < Packcr::Node
      attr_accessor :value

      def initialize(value = nil)
        @value = value
      end

      def debug_dump(indent = 0)
        $stdout.print "#{" " * indent}Charclass(value:'"
        Packcr.dump_escaped_string(value)
        $stdout.print "')\n"
      end

      def reversible?(gen)
        gen.lang == :rb && !gen.ascii
      end

      def generate_code(gen, onfail, indent, bare, oncut: nil)
        return generate_ascii_code(gen, onfail, indent, bare) if gen.ascii

        generate_utf8_charclass_code(gen, onfail, indent, bare)
      end

      def generate_reverse_code(gen, onsuccess, indent, bare, oncut: nil)
        raise "unexpected" if gen.ascii

        generate_utf8_charclass_reverse_code(gen, onsuccess, indent, bare)
      end

      def reachability
        charclass = value
        n = charclass&.length || 0
        return Packcr::CODE_REACH__BOTH if charclass.nil? || n > 0

        Packcr::CODE_REACH__ALWAYS_FAIL
      end

      private

      def generate_utf8_charclass_code(gen, onfail, indent, bare)
        charclass = value
        if charclass && charclass.encoding != Encoding::UTF_8
          charclass = charclass.dup.force_encoding(Encoding::UTF_8)
        end
        n = charclass&.length || 0
        if charclass.nil? || n > 0
          gen.write Packcr.template("node/charclass_utf8.#{gen.lang}.erb", binding, indent: indent, unwrap: bare)
        else
          gen.write Packcr.template("node/charclass_fail.#{gen.lang}.erb", binding, indent: indent)
        end
      end

      def generate_utf8_charclass_reverse_code(gen, onsuccess, indent, bare)
        charclass = value
        if charclass && charclass.encoding != Encoding::UTF_8
          charclass = charclass.dup.force_encoding(Encoding::UTF_8)
        end
        n = charclass&.length || 0
        return unless charclass.nil? || n > 0

        gen.write Packcr.template("node/charclass_utf8_reverse.#{gen.lang}.erb", binding, indent: indent, unwrap: bare)
      end

      def generate_ascii_code(gen, onfail, indent, bare)
        charclass = value
        if charclass
          n = charclass.length
          a = charclass[0] == "^"
          if a
            n -= 1
            charclass = charclass[1..-1]
          end
          if n > 0
            if n > 1
              gen.write Packcr.template("node/charclass.#{gen.lang}.erb", binding, indent: indent, unwrap: bare)
            else
              gen.write Packcr.template("node/charclass_one.#{gen.lang}.erb", binding, indent: indent)
            end
          else
            gen.write Packcr.template("node/charclass_fail.#{gen.lang}.erb", binding, indent: indent)
          end
        else
          gen.write Packcr.template("node/charclass_any.#{gen.lang}.erb", binding, indent: indent)
        end
      end

      def to_h
        {
          type: :charclass,
          value: value,
        }
      end
    end
  end
end
