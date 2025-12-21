module Biryani
  module Frame
    class Settings
      attr_reader :f_type, :stream_id, :setting

      # @param ack [Boolean]
      # @param stream_id [Integer]
      # @param setting [Hash<Integer, Integer>] uint16 uint32
      def initialize(ack, stream_id, setting)
        @f_type = FrameType::SETTINGS
        @ack = ack
        @stream_id = stream_id
        @setting = setting
      end

      # @return [Boolean]
      def ack?
        @ack
      end

      # @return [Integer]
      def length
        @setting.length * 6
      end

      # @return [String]
      def to_binary_s
        payload_length = length
        flags = Frame.to_flags(ack: ack?)
        setting = @setting.map { |x| x.pack('nN') }.join

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + setting
      end

      # @param s [String]
      #
      # @return [Settings]
      def self.read(s)
        payload_length, _, flags, stream_id = Frame.read_header(s)
        raise Error::FrameReadError if payload_length % 6 != 0

        ack = Frame.read_ack(flags)
        setting = s[9..].unpack('nN' * (payload_length / 6)).each_slice(2).to_h

        Settings.new(ack, stream_id, setting)
      end
    end
  end
end
