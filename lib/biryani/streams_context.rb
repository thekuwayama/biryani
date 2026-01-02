module Biryani
  class StreamsContext
    def initialize
      @h = {}
    end

    # @param stream_id [Integer]
    # @param send_initial_window_size [Integer]
    # @param recv_initial_window_size [Integer]
    # @param proc [Proc]
    #
    # @return [StreamContext]
    def new_context(stream_id, send_initial_window_size, recv_initial_window_size, proc)
      ctx = StreamContext.new(stream_id, send_initial_window_size, recv_initial_window_size, proc)
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

    # @return [Array<Port>]
    def txs
      @h.values.filter { |ctx| !ctx.closed? }.map(&:tx)
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
      @h.reject { |_, ctx| ctx.idle? }.keys.max || 0
    end

    # @param data_buffer [DataBuffer]
    def remove_closed(data_buffer)
      closed_ids = closed_stream_ids.filter { |id| !data_buffer.has?(id) }
      closed_ids.each do |id|
        @h[id].tx.close
        @h[id].stream.rx << nil
        @h[id].fragment.close
        @h[id].content.close
      end
    end

    def close_all
      each do |ctx|
        ctx.tx.close
        ctx.fragment.close
        ctx.content.close
        ctx.state.close
      end
    end

    def clear_all
      each do |ctx|
        ctx.tx.close
        ctx.stream.rx << nil
        ctx.fragment.close
        ctx.content.close
      end
    end
  end

  class StreamContext
    attr_accessor :stream, :tx, :send_window, :recv_window, :fragment, :content, :state

    # @param stream_id [Integer]
    # @param send_initial_window_size [Integer]
    # @param recv_initial_window_size [Integer]
    # @param proc [Proc]
    def initialize(stream_id, send_initial_window_size, recv_initial_window_size, proc)
      @tx = Ractor::Port.new
      @stream = Stream.new(@tx, stream_id, proc)
      @send_window = Window.new(send_initial_window_size)
      @recv_window = Window.new(recv_initial_window_size)
      @fragment = StringIO.new
      @content = StringIO.new
      @state = State.new
    end

    # @return [Boolean]
    def closed?
      @state.closed?
    end

    # @return [Boolean]
    def idle?
      @state.idle?
    end

    # @return [Boolean]
    def active?
      @state.active?
    end
  end
end
