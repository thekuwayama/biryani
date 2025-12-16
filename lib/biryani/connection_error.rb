module Biryani
  class ConnectionError
    # @param code [Integer]
    # @param debug [String]
    def initialize(code, debug)
      @code = code
      @debug = debug
    end

    # @param last_stream_id [Integer]
    #
    # @return [Goaway]
    def goaway(last_stream_id)
      Frame::Goaway.new(last_stream_id, @code, @debug)
    end
  end
end
