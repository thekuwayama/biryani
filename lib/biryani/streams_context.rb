module Biryani
  class StreamsContext
    def initialize
      @h = {}
    end

    # @param stream_id [Integer]
    #
    # @return [StreamContext]
    def new_context(stream_id)
      ctx = StreamContext.new(stream_id)
      @h[stream_id] = ctx
      ctx
    end

    # @param stream_id [Integer]
    def delete(stream_id)
      @h.delete(stream_id)
    end

    # @param stream_id [Integer]
    #
    # @return [StreamContext, nil]
    def [](stream_id)
      @h[stream_id]
    end

    # @return [Integer]
    def length
      @h.length
    end

    def each(&block)
      @h.each_value(&block)
    end

    # @return [Array<Ractor>] ports
    def txs
      @h.values.filter { |ctx| !ctx.closed? }.map(&:tx)
    end

    # @return [Array<Ractor>] ports
    def errs
      @h.values.map(&:err)
    end

    # @return [Integer]
    def count_active
      @h.values.filter(&:active?).length
    end

    # @return [Array<Integer>]
    def closed_stream_ids
      @h.filter { |_, ctx| ctx.closed? }.keys
    end

    # @return [Integer]
    def last_stream_id
      @h.keys.max || 0
    end
  end

  class StreamContext
    include Port
    attr_accessor :stream, :tx, :err, :send_window, :recv_window, :fragment, :content, :state

    # @param stream_id [Integer]
    def initialize(stream_id)
      @tx = port
      @err = port
      @stream = Stream.new(stream_id, @tx, @err)
      @send_window = Window.new
      @recv_window = Window.new
      @fragment = StringIO.new
      @content = StringIO.new
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
