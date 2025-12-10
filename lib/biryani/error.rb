module Biryani
  module Error
    # Generic error, common for all classes under Biryani::Error module.
    class Error < StandardError; end

    class HuffmanDecodeError < Error; end

    class ConnectionError < Error
      # @param code [Integer]
      # @param debug [String]
      def initialize(code, debug)
        @code = code
        @debug = debug
        super(debug)
      end

      # @param last_stream_id [Integer]
      #
      # @return [Goaway]
      def goaway(last_stream_id)
        Frame::Goaway.new(last_stream_id, @code, @debug)
      end

      class StreamError < Error
        # @param code [Integer]
        # @param stream_id [stream_id]
        def initialize(code, stream_id, msg)
          @code = code
          @stream_id = stream_id
          super(msg)
        end

        # @return [RstStream]
        def rst_stream
          Frame::RstStream.new(@stream_id, @code)
        end
      end
    end
  end
end
