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
    # rubocop: disable Metrics/AbcSize
    def take!(send_window, streams_ctx, max_frame_size)
      datas = []
      @buffer.each do |stream_id, data|
        len = Connection.sendable_length(data.bytesize, stream_id, send_window, streams_ctx)
        next if len.zero?

        if @buffer[stream_id].bytesize > len
          payload = @buffer[stream_id][0...len]
          @buffer[stream_id] = @buffer[stream_id][len..]
          remained = true
        else
          payload = @buffer[stream_id]
          @buffer.delete(stream_id)
          remained = false
        end

        len = (payload.length + max_frame_size - 1) / max_frame_size
        datas += payload.gsub(/.{1,#{max_frame_size}}/m).with_index.map do |s, index|
          end_stream = !remained && index == len - 1
          Frame::Data.new(end_stream, stream_id, s, nil)
        end

        send_window.consume!(payload.length)
        streams_ctx[stream_id].send_window.consume!(payload.length)
      end

      datas
    end
    # rubocop: enable Metrics/AbcSize

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
