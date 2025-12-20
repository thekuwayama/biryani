module Biryani
  class StreamContext
    include Port
    attr_accessor :stream, :tx, :err, :send_window, :recv_window, :state

    def initialize
      @tx = port
      @err = port
      @stream = Stream.new(@tx, @err)
      @send_window = Window.new
      @recv_window = Window.new
      @state = State.new
    end

    # @return [Boolean]
    def closed?
      @state.closed?
    end

    # @return [Boolean]
    def active?
      @state.active?
    end
  end
end
