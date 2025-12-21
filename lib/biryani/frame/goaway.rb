module Biryani
  module Frame
    class Goaway
      attr_reader :f_type, :stream_id, :last_stream_id, :error_code, :debug

      # @param last_stream_id [Integer]
      # @param error_code [Integer]
      # @param debug [String]
      def initialize(stream_id, last_stream_id, error_code, debug)
        @f_type = FrameType::GOAWAY
        @stream_id = stream_id
        @last_stream_id = last_stream_id
        @error_code = error_code
        @debug = debug
      end

      # @return [Integer]
      def length
        @debug.bytesize + 8
      end

      # @return [String]
      def to_binary_s
        payload_length = length
        flags = 0x00

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + [@last_stream_id, @error_code].pack('NN') + @debug
      end

      # @param s [String]
      #
      # @return [Goaway]
      def self.read(s)
        _, _, _, stream_id = Frame.read_header(s)
        last_stream_id, error_code = s[9..16].unpack('NN')
        debug = s[17..]

        Goaway.new(stream_id, last_stream_id, error_code, debug)
      end
    end
  end
end
