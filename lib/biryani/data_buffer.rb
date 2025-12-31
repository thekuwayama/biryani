module Biryani
  class DataBuffer
    def initialize
      @buffer = {} # Hash<Integer, String>
    end

    # @param stream_id [Integer]
    # @param data [String]
    def store(stream_id, data)
      @buffer[stream_id] = '' unless @buffer.key?(stream_id)
      @buffer[stream_id] += data
    end

    # @param send_window [Window]
    # @param streams_ctx [StreamsContext]
    # @param max_frame_size [Intger]
    #
    # @return [Array<Object>] frames
    def take!(send_window, streams_ctx, max_frame_size)
      datas = []
      @buffer.each do |stream_id, data|
        frames, remains = Connection.sendable_data_frames(data, stream_id, send_window, max_frame_size, streams_ctx)
        next if frames.empty?

        datas += frames
        if remains.empty?
          @buffer.delete(stream_id)
        else
          @buffer[stream_id] = remains
        end

        len = frames.map(&:length).sum
        send_window.consume!(len)
        streams_ctx[stream_id].send_window.consume!(len)
      end

      datas
    end

    # @return [Integer]
    def length
      @buffer.length
    end

    # @param stream_id [Integer]
    #
    # @return [Boolean]
    def has?(stream_id)
      @buffer.key?(stream_id)
    end
  end
end
