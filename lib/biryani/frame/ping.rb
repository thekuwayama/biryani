module Biryani
  module Frame
    class Ping
      attr_reader :f_type, :stream_id, :opaque

      # @param ack [Boolean]
      # @param opaque [String]
      def initialize(ack, opaque)
        @f_type = FrameType::PING
        @ack = ack
        @stream_id = 0
        @opaque = opaque
      end

      # @return [Boolean]
      def ack?
        @ack
      end

      # @return [String]
      def to_binary_s
        payload_length = 8
        flags = Frame.to_flags(ack: ack?)

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + opaque
      end

      # @param s [String]
      #
      # @return [Ping]
      def self.read(s)
        _, _, flags, = Frame.read_header(s)
        ack = Frame.read_ack(flags)
        opaque = s[9..]

        Ping.new(ack, opaque)
      end
    end
  end
end
