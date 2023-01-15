class Packcr
  class BroadCast
    def initialize(*arrays)
      @arrays = arrays
    end

    def <<(obj)
      @arrays.each do |array|
        array << obj
      end
    end

    def to_ary
      @arrays
    end
  end
end
