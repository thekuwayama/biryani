module Biryani
  module Frame
    class PushPromise
      attr_reader :f_type, :stream_id, :promised_stream_id, :fragment, :padding

      # @param end_headers [Boolean]
      # @param stream_id [Integer]
      # @param promised_stream_id [Integer]
      # @param fragment [String]
      # @param padding [String, nil]
      def initialize(end_headers, stream_id, promised_stream_id, fragment, padding)
        @f_type = FrameType::PUSH_PROMISE
        @end_headers = end_headers
        @stream_id = stream_id
        @promised_stream_id = promised_stream_id
        @fragment = fragment
        @padding = padding
      end

      # @return [Boolean]
      def padded?
        !@padding.nil?
      end

      # @return [Boolean]
      def end_headers?
        @end_headers
      end

      # @return [Integer]
      def length
        @fragment.bytesize + 4 + (padded? ? 1 + @padding.bytesize : 0)
      end

      # @return [String]
      def to_binary_s
        payload_length = length
        flags = Frame.to_flags(padded: padded?, end_headers: end_headers?)
        pad_length = padded? ? @padding.bytesize.chr : ''
        padding = @padding || ''

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + pad_length + [@promised_stream_id].pack('N') + @fragment + padding
      end

      # @param s [String]
      # @param flags [Integer]
      # @param stream_id [Integer]
      #
      # @return [PushPromise]
      def self.read(s, flags, stream_id)
        padded = Frame.read_padded(flags)
        end_headers = Frame.read_end_headers(flags)

        io = IO::Buffer.for(s)
        if padded
          pad_length, promised_stream_id = io.get_values(%i[U8 U32], 0)
          promised_stream_id %= 2**31 # Promised Stream ID (31)
          fragment_length = s.bytesize - pad_length - 5
          fragment = io.get_string(5, fragment_length)
          padding = io.get_string(5 + fragment_length)
          return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid frame') if pad_length >= s.bytesize
          return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid frame') if padding.bytesize != pad_length
        else
          promised_stream_id = io.get_value(:U32, 0)
          promised_stream_id %= 2**31 # Promised Stream ID (31)
          fragment = io.get_string(4)
          return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid frame') if fragment.bytesize + 4 != s.bytesize
        end

        PushPromise.new(end_headers, stream_id, promised_stream_id, fragment, padding)
      end
    end
  end
end
