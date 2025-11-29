require_relative 'window'

module Biryani
  class StreamContext
    attr_accessor :stream, :tx, :send_window, :recv_window

    def initialize
      @stream = Stream.new
      @tx = channel
      @send_window = Window.new
      @recv_window = Window.new
    end

    # @return [Ractor]
    def channel
      Ractor.new do
        loop do
          Ractor.yield Ractor.receive
        end
      end
    end
  end
end
