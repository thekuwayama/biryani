module Biryani
  class StreamContext
    attr_accessor :stream, :tx, :send_window, :recv_window, :state

    def initialize
      @tx = channel
      @stream = Stream.new(@tx)
      @send_window = Window.new
      @recv_window = Window.new
      @state = State.new
    end

    # @return [Ractor]
    def channel
      Ractor.new do
        loop do
          # TODO: using Ractor::Port.new for Ruby 4.0
          Ractor.yield Ractor.receive
        end
      end
    end

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
