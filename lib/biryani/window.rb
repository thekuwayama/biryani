module Biryani
  class Window
    # @param initial_window_size [Integer]
    def initialize(initial_window_size)
      @window = initial_window_size
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
