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

      # @return [String]
      def to_binary_s
        payload_length = 4
        flags = 0x00

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + [@window_size_increment].pack('N')
      end

      # @param s [String]
      #
      # @return [WindowUpdate]
      def self.read(s)
        _, _, _, stream_id = Frame.read_header(s)
        window_size_increment = s[9..].unpack1('N') % 2**31

        WindowUpdate.new(stream_id, window_size_increment)
      end
    end
  end
end
