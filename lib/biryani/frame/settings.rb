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
      # rubocop: disable Metrics/CyclomaticComplexity
      # rubocop: disable Metrics/PerceivedComplexity
      def self.read(s)
        payload_length, _, flags, stream_id = Frame.read_header(s)
        return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'invalid frame') if payload_length % 6 != 0

        ack = Frame.read_ack(flags)
        setting = s[9..].unpack('nN' * (payload_length / 6)).each_slice(2).to_h
        return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'ack SETTINGS invalid setting') \
          if ack && setting.any?
        return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid SETTINGS_MAX_FRAME_SIZE') \
          if setting.key?(SettingsID::SETTINGS_MAX_FRAME_SIZE) && setting[SettingsID::SETTINGS_MAX_FRAME_SIZE] < 16_384
        return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid SETTINGS_MAX_FRAME_SIZE') \
          if setting.key?(SettingsID::SETTINGS_MAX_FRAME_SIZE) && setting[SettingsID::SETTINGS_MAX_FRAME_SIZE] > 16_777_215
        return ConnectionError.new(ErrorCode::FLOW_CONTROL_ERROR, 'invalid SETTINGS_INITIAL_WINDOW_SIZE') \
          if setting.key?(SettingsID::SETTINGS_INITIAL_WINDOW_SIZE) && setting[SettingsID::SETTINGS_INITIAL_WINDOW_SIZE] > 2_147_483_647

        Settings.new(ack, stream_id, setting)
      end
      # rubocop: enable Metrics/CyclomaticComplexity
      # rubocop: enable Metrics/PerceivedComplexity
    end
  end
end
