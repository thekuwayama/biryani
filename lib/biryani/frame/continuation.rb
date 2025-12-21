module Biryani
  module Frame
    class Continuation
      attr_reader :f_type, :stream_id, :fragment

      # @param end_headers [Boolean]
      # @param stream_id [Integer]
      # @param fragment [String]
      def initialize(end_headers, stream_id, fragment)
        @f_type = FrameType::CONTINUATION
        @end_headers = end_headers
        @stream_id = stream_id
        @fragment = fragment
      end

      # @return [Boolean]
      def end_headers?
        @end_headers
      end

      # @return [Integer]
      def length
        @fragment.bytesize
      end

      # @return [String]
      def to_binary_s
        payload_length = length
        flags = Frame.to_flags(end_headers: end_headers?)

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + @fragment
      end

      # @param s [String]
      #
      # @return [Data]
      def self.read(s)
        _, _, flags, stream_id = Frame.read_header(s)
        end_headers = Frame.read_end_headers(flags)
        fragment = s[9..]

        Continuation.new(end_headers, stream_id, fragment)
      end

      # @param decoder [Decoder]
      #
      # @return [RawContinuation]
      def decode(decoder)
        fields = decoder.decode(@fragment)

        RawContinuation.new(@end_headers, @stream_id, fields)
      rescue Error::HuffmanDecodeError, Error::HPACKDecodeError
        ConnectionError.new(ErrorCode::COMPRESSION_ERROR, 'hpack decode error')
      end
    end
  end
end
