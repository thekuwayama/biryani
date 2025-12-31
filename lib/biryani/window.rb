module Biryani
  class Window
    attr_reader :length

    # @param initial_window_size [Integer]
    def initialize(initial_window_size)
      @length = initial_window_size
      @capacity = initial_window_size
    end

    # @param length [Integer]
    def consume!(length)
      @length -= length
    end

    # @param length [Integer]
    def increase!(length)
      @length += length
    end

    # @param initial_window_size [Integer]
    def update!(initial_window_size)
      @length = initial_window_size - (@capacity - @length)
      @capacity = initial_window_size
    end
  end
end
