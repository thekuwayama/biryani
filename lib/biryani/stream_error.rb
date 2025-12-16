module Biryani
  class StreamError
    # @param code [Integer]
    # @param stream_id [stream_id]
    # @param debug [String]
    def initialize(code, stream_id, debug)
      @code = code
      @stream_id = stream_id
      @debug = debug
    end

    # @return [RstStream]
    def rst_stream
      Frame::RstStream.new(@stream_id, @code)
    end
  end
end
