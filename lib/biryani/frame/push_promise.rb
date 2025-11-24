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

      # @return [String]
      def to_binary_s
        payload_length = @fragment.bytesize + 4 + (padded? ? 1 + @padding.bytesize : 0)
        flags = Frame.to_flags(padded: padded?, end_headers: end_headers?)
        pad_length = padded? ? @padding.bytesize.chr : ''
        padding = @padding || ''

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + pad_length + [@promised_stream_id].pack('N') + @fragment + padding
      end

      # @param s [String]
      #
      # @return [PushPromise]
      def self.read(s)
        payload_length, _, flags, stream_id = Frame.read_header(s)
        padded = Frame.read_padded(flags)
        end_headers = Frame.read_end_headers(flags)

        if padded
          pad_length = s[9].unpack1('C')
          promised_stream_id = s[10..13].unpack1('N')
          fragment_length = payload_length - pad_length - 5
          fragment = s[14...14 + fragment_length]
          padding = s[14 + fragment_length..]
        else
          promised_stream_id = s[9..12].unpack1('N')
          fragment = s[13..]
        end

        PushPromise.new(end_headers, stream_id, promised_stream_id, fragment, padding)
      end
    end
  end
end
