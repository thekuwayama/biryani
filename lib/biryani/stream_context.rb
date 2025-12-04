module Biryani
  class StreamContext
    attr_accessor :stream, :tx, :send_window, :recv_window

    def initialize
      @tx = channel
      @stream = Stream.new(@tx)
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

    def close
      @closed = true
    end

    # @return [Boolean]
    def closed?
      @closed
    end
  end
end
