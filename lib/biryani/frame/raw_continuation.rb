module Biryani
  module Frame
    class RawContinuation
      attr_reader :f_type, :stream_id, :fields

      # @param end_headers [Boolean]
      # @param stream_id [Integer]
      # @param fields [String]
      def initialize(end_headers, stream_id, fields)
        @f_type = FrameType::CONTINUATION
        @end_headers = end_headers
        @stream_id = stream_id
        @fields = fields
      end

      # @return [Boolean]
      def end_headers?
        @end_headers
      end

      # @param encoder [Encoder]
      #
      # @return [Continuation]
      def encode(encoder)
        fragment = encoder.encode(@fields)

        Continuation.new(@end_headers, @stream_id, fragment)
      end
    end
  end
end
