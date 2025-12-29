module Biryani
  class HTTPResponse
    attr_accessor :status, :fields, :content

    # @param status [Integer]
    # @param fields [Hash]
    # @param content [String]
    def initialize(status, fields, content)
      @status = status
      @fields = fields
      @content = content
    end

    # @return [HTTPResponse]
    def self.internal_error
      HTTPResponse.new(500, {}, 'Internal Server Error')
    end
  end

  class HTTPResponseParser
    # @param res [HTTPResponse]
    def initialize(res)
      @res = res
    end

    # @return [Array]
    def fields
      fields = [[':status', @res.status.to_s]]
      @res.fields.each do |name, value|
        # TODO: validate fields
        fields << [name.to_s.downcase, value.to_s]
      end

      fields
    end

    # @return [String]
    def content
      @res.content
    end

    # @param stream_id [Integer]
    # @param encoder [Encoder]
    # @param max_frame_size [Integer]
    #
    # @return [Array<Object>] frames
    def parse(stream_id, encoder, max_frame_size)
      fragment = encoder.encode(fields)
      len = (fragment.bytesize + max_frame_size - 1) / max_frame_size
      frames = fragment.gsub(/.{1,#{max_frame_size}}/m).with_index.map do |s, index|
        if index.zero?
          Frame::Headers.new(len < 2, content.empty?, stream_id, nil, nil, s, nil)
        else
          Frame::Continuation.new(index == len - 1, stream_id, s)
        end
      end

      len = (content.bytesize + max_frame_size - 1) / max_frame_size
      frames += content.gsub(/.{1,#{max_frame_size}}/m).with_index.map do |s, index|
        Frame::Data.new(index == len - 1, stream_id, s, nil)
      end

      frames
    end
  end
end
