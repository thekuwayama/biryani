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

    # @return [:idle, :open, :reserved_local, :reserved_remote, :half_closed_local, :half_closed_remote, :closed]
    attr_writer :state

    # @return [Boolean]
    def closed?
      @state == :closed
    end

    # @return [Boolean]
    def active?
      @state == :open || @state == :half_closed_local || @state == :half_closed_remote
    end
  end
end
