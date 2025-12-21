module Biryani
  module Frame
    class Data
      attr_reader :f_type, :stream_id, :data, :padding

      # @param end_stream [Boolean]
      # @param stream_id [Integer]
      # @param data [String]
      # @param padding [String, nil]
      def initialize(end_stream, stream_id, data, padding)
        @f_type = FrameType::DATA
        @end_stream = end_stream
        @stream_id = stream_id
        @data = data
        @padding = padding
      end

      # @return [Boolean]
      def padded?
        !@padding.nil?
      end

      # @return [Boolean]
      def end_stream?
        @end_stream
      end

      # @return [Integer]
      def length
        @data.bytesize + (padded? ? 1 + @padding.bytesize : 0)
      end

      # @return [String]
      def to_binary_s
        payload_length = length
        flags = Frame.to_flags(padded: padded?, end_stream: end_stream?)
        pad_length = padded? ? @padding.bytesize.chr : ''
        padding = @padding || ''

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + pad_length + @data + padding
      end

      # @param s [String]
      #
      # @return [Data]
      def self.read(s)
        payload_length, _, flags, stream_id = Frame.read_header(s)
        padded = Frame.read_padded(flags)
        end_stream = Frame.read_end_stream(flags)

        if padded
          pad_length = s[9].unpack1('C')
          data_length = payload_length - pad_length - 1
          data = s[10...10 + data_length]
          padding = s[10 + data_length..]
          return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'invalid frame') if padding.bytesize != pad_length
        else
          data = s[9..]
          padding = nil
          return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'invalid frame') if data.bytesize != payload_length
        end

        Data.new(end_stream, stream_id, data, padding)
      end
    end
  end
end
