module Biryani
  class DataBuffer
    def initialize
      @buffer = [] # Array<Data>
    end

    # @param data [Data]
    def <<(data)
      @buffer << data
    end

    # @param send_window [Window]
    # @param stream_ctxs [Hash<Integer, StreamContext>]
    #
    # @return [Array<Data>]
    def take!(send_window, stream_ctxs)
      datas = {}
      @buffer.each_with_index.each do |data, i|
        next unless Connection.sendable?(data, send_window, stream_ctxs)

        send_window.consume!(data.length)
        stream_ctxs[data.stream_id].send_window.consume!(data.length)
        datas[i] = data
      end

      @buffer = @buffer.each_with_index.filter { |_, i| datas.keys.include?(i) }.map(&:first)
      datas.values
    end

    # @return [Integer]
    def length
      @buffer.length
    end
  end
end
