
class Packcr
  class Buffer
    def initialize
      @buf = +"".b
    end

    def len
      @buf.length
    end

    def [](index)
      @buf[index].ord
    end

    def count_characters(s, e)
      # UTF-8 multibyte character support but without checking UTF-8 validity
      n = 0
      i = s
      while i < e
        c = self[i]
        if c == 0
          break
        end
        n += 1
        i += (c < 0x80) ? 1 : ((c & 0xe0) == 0xc0) ? 2 : ((c & 0xf0) == 0xe0) ? 3 : ((c & 0xf8) == 0xf0) ? 4 : 1
      end
      return n
    end

    def add(ch)
      @buf.concat(ch)
    end

    def to_s
      @buf
    end

    def []=(pos, ch)
      @buf[pos] = ch.chr
    end

    def add_pos(offset)
      @buf[0, offset] = ""
    end
  end
end