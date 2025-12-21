module Biryani
  module Frame
    class WindowUpdate
      attr_reader :f_type, :stream_id, :window_size_increment

      # @param stream_id [Integer]
      # @param window_size_increment [Integer]
      def initialize(stream_id, window_size_increment)
        @f_type = FrameType::WINDOW_UPDATE
        @stream_id = stream_id
        @window_size_increment = window_size_increment
      end

      # @return [Integer]
      def length
        4
      end

      # @return [String]
      def to_binary_s
        payload_length = length
        flags = 0x00

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + [@window_size_increment].pack('N')
      end

      # @param s [String]
      #
      # @return [WindowUpdate]
      def self.read(s)
        payload_length, _, _, stream_id = Frame.read_header(s)
        return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'invalid frame') if payload_length != 4 || s[9..].bytesize != 4

        window_size_increment = s[9..].unpack1('N')
        return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'WINDOW_UPDATE invalid window size increment 0') if window_size_increment.zero?
        return ConnectionError.new(ErrorCode::FLOW_CONTROL_ERROR, 'WINDOW_UPDATE invalid window size increment greater than 2^31-1') if window_size_increment > 2**31 - 1

        WindowUpdate.new(stream_id, window_size_increment)
      end
    end
  end
end
