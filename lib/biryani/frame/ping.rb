module Biryani
  module Frame
    class Ping
      attr_reader :f_type, :stream_id, :opaque

      # @param ack [Boolean]
      # @param stream_id [Integer]
      # @param opaque [String]
      def initialize(ack, stream_id, opaque)
        @f_type = FrameType::PING
        @ack = ack
        @stream_id = stream_id
        @opaque = opaque
      end

      # @return [Boolean]
      def ack?
        @ack
      end

      # @return [Integer]
      def length
        8
      end

      # @return [String]
      def to_binary_s
        payload_length = length
        flags = Frame.to_flags(ack: ack?)

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + opaque
      end

      # @param s [String]
      #
      # @return [Ping]
      def self.read(s)
        payload_length, _, flags, stream_id = Frame.read_header(s)
        return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid frame') if s[9..].bytesize != payload_length
        return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'PING payload length MUST be 8') if s[9..].bytesize != 8

        ack = Frame.read_ack(flags)
        opaque = s[9..]

        Ping.new(ack, stream_id, opaque)
      end
    end
  end
end
