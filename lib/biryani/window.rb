module Biryani
  class Window
    def initialize
      @window = 2**16 - 1
    end

    # @param length [Integer]
    #
    # @return [Boolean]
    def available?(length)
      @window > length
    end

    # @param length [Integer]
    def consume!(length)
      @window -= length
    end

    # @param length [Integer]
    def increase!(length)
      @window += length
    end

    # @return [Integer]
    def length
      @window
    end
  end
end
