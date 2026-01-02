module Biryani
  class Window
    attr_reader :length, :capacity

    # @param initial_window_size [Integer]
    def initialize(initial_window_size)
      @length = initial_window_size
      @capacity = initial_window_size
    end

    # @param length [Integer]
    #
    # @return [Integer]
    def consume!(length)
      @length -= length
    end

    # @param length [Integer]
    #
    # @return [Integer]
    def increase!(length)
      @length += length
    end

    # @param initial_window_size [Integer]
    #
    # @return [Integer]
    def update!(initial_window_size)
      @length = initial_window_size - @capacity + @length
      @capacity = initial_window_size
      @length
    end
  end
end
