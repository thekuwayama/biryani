module Biryani
  module Frame
    class Settings
      attr_reader :f_type, :stream_id, :setting

      # @param ack [Boolean]
      # @param setting [Array] [[uint16, uint32], ...]
      def initialize(ack, setting)
        @f_type = FrameType::SETTINGS
        @ack = ack
        @stream_id = 0
        @setting = setting
      end

      # @return [Boolean]
      def ack?
        @ack
      end

      # @return [String]
      def to_binary_s
        payload_length = setting.length * 6
        flags = Frame.to_flags(ack: ack?)
        setting = @setting.map { |x| x.pack('nN') }.join

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + setting
      end

      # @param s [String]
      #
      # @return [Settings]
      def self.read(s)
        _, _, flags, = Frame.read_header(s)
        ack = Frame.read_ack(flags)
        setting = s[9..].unpack('nN' * (s[9..].bytesize / 6)).each_slice(2).to_a

        Settings.new(ack, setting)
      end
    end
  end
end
