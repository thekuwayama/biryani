module Biryani
  module Frame
    class Unknown
      attr_reader :f_type, :flags, :stream_id, :payload

      # @param f_type [Integer]
      # @param flags [Integer]
      # @param stream_id [Integer]
      # @param payload [String, nil]
      def initialize(f_type, flags, stream_id, payload)
        @f_type = f_type
        @flags = flags
        @stream_id = stream_id
        @payload = payload
      end

      # @return [Integer]
      def length
        @payload.bytesize
      end

      # @return [String]
      def to_binary_s
        payload_length = length

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + @payload
      end

      # @param s [String]
      #
      # @return [Data]
      def self.read(s)
        payload_length, f_type, flags, stream_id = Frame.read_header(s)
        payload = s[9..]
        return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'invalid frame') if payload.bytesize != payload_length

        Unknown.new(f_type, flags, stream_id, payload)
      end
    end
  end
end
