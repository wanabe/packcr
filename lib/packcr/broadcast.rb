class Packcr
  class BroadCaster
    def initialize(arrays)
      @arrays = arrays
    end

    def <<(obj)
      @arrays.each do |array|
        array << obj
      end
    end
  end
end
