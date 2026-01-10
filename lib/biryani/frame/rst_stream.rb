module Biryani
  module Frame
    class RstStream
      attr_reader :f_type, :stream_id, :error_code

      # @param stream_id [Integer]
      # @param error_code [Integer]
      def initialize(stream_id, error_code)
        @f_type = FrameType::RST_STREAM
        @stream_id = stream_id
        @error_code = error_code
      end

      # @return [Integer]
      def length
        4
      end

      # @return [String]
      def to_binary_s
        payload_length = length
        flags = 0x00

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + [@error_code].pack('N')
      end

      # @param s [String]
      # @param _flags [Integer]
      # @param stream_id [Integer]
      #
      # @return [RstStream]
      def self.read(s, _flags, stream_id)
        return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'RST_STREAM payload length MUST be 4') if s.bytesize != 4

        error_code = s.unpack1('N')
        RstStream.new(stream_id, error_code)
      end
    end
  end
end
