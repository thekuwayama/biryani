module Biryani
  class HTTPResponseParser
    # @param status [Integer]
    # @param h [Hash]
    # @param s [String]
    # @param stream_id [Integer]
    def initialize(status, h, s, stream_id)
      @status = status
      @h = h
      @s = s
      @stream_id = stream_id
    end

    # @return [Array]
    def fields
      fields = [[':status', @status.to_s]]
      @h.each do |name, value|
        # TODO: validate fields
        fields << [name.to_s.downcase, value.to_s]
      end

      fields
    end

    # @param encoder [Encoder]
    # @param max_frame_size [Integer]
    #
    # @return [Array<Object>] frames
    def parse(encoder, max_frame_size)
      fragment = encoder.encode(fields)
      len = (fragment.bytesize + max_frame_size - 1) / max_frame_size
      frames = fragment.gsub(/.{1,#{max_frame_size}}/m).with_index.map do |s, index|
        if index.zero?
          Frame::Headers.new(len < 2, @s.empty?, @stream_id, nil, nil, s, nil)
        else
          Frame::Continuation.new(index == len - 1, @stream_id, s)
        end
      end

      len = (@s.bytesize + max_frame_size - 1) / max_frame_size
      frames += @s.gsub(/.{1,#{max_frame_size}}/m).with_index.map do |s, index|
        Frame::Data.new(index == len - 1, @stream_id, s, nil)
      end

      frames
    end
  end
end
