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
      # @param flags [Integer]
      # @param stream_id [Integer]
      #
      # @return [Ping]
      def self.read(s, flags, stream_id)
        return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'PING payload length MUST be 8') if s.bytesize != 8

        ack = Frame.read_ack(flags)
        Ping.new(ack, stream_id, s)
      end
    end
  end
end
