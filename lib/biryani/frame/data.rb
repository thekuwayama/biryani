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
      # @param flags [Integer]
      # @param stream_id [Integer]
      #
      # @return [Data]
      def self.read(s, flags, stream_id)
        padded = Frame.read_padded(flags)
        end_stream = Frame.read_end_stream(flags)

        if padded
          io = IO::Buffer.for(s)
          pad_length = io.get_value(:U8, 0)
          data_length = s.bytesize - pad_length - 1
          data = io.get_string(1, data_length)
          padding = io.get_string(1 + data_length)
          return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid frame') if padding.bytesize != pad_length
        else
          data = s
        end

        Data.new(end_stream, stream_id, data, padding)
      end
    end
  end
end
