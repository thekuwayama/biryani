module Biryani
  module Frame
    class Priority
      attr_reader :f_type, :stream_id, :stream_dependency, :weight

      # @param stream_id [Integer]
      # @param stream_dependency [Integer]
      # @param weight [Integer]
      def initialize(stream_id, stream_dependency, weight)
        @f_type = FrameType::PRIORITY
        @stream_id = stream_id
        @stream_dependency = stream_dependency
        @weight = weight
      end

      # @return [Integer]
      def length
        5
      end

      # @return [String]
      def to_binary_s
        payload_length = length
        flags = 0x00

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + [@stream_dependency, @weight].pack('NC')
      end

      # @param s [String]
      #
      # @return [Priority]
      def self.read(s)
        payload_length, _, _, stream_id = Frame.read_header(s)
        return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid frame') if s[9..].bytesize != payload_length
        return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'PRIORITY payload length MUST be 5') if payload_length != 5

        stream_dependency, weight = s[9..13].unpack('NC')
        stream_dependency %= 2**31
        return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'cannot depend on itself') if stream_dependency == stream_id

        Priority.new(stream_id, stream_dependency, weight)
      end
    end
  end
end
