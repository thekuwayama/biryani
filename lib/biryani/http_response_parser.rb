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
        # TODO: modify pseudo-header
        fields << [name.to_s.downcase, value.to_s]
      end

      fields
    end

    # @return [String]
    def content
      @s
    end

    # @param stream_id [Integer]
    #
    # @return [Array<Object>] frames
    def parse
      # TODO: encode
      # TODO: divide fragment with max_frame_size
      headers = Frame::RawHeaders.new(true, false, @stream_id, nil, nil, fields, nil)
      return [headers] if content.empty?

      data = Frame::Data.new(true, @stream_id, content, nil)
      [headers, data]
    end
  end
end
