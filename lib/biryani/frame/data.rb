module Biryani
  module Frame
    class Data
      attr_reader :f_type, :end_stream, :stream_id, :data, :padding

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

      # @return [String]
      def to_binary_s
        payload_length = [@data.bytesize + (padded? ? 1 + @padding.bytesize : 0)].pack('N1')[1..]
        f_type = @f_type.chr
        flags = ((padded? ? 8 : 0) + (@end_stream ? 1 : 0)).chr
        stream_id = [@stream_id].pack('N1')
        pad_length = padded? ? @padding.bytesize.chr : ''
        padding = @padding || ''

        payload_length + f_type + flags + stream_id + pad_length + @data + padding
      end

      # @params s [String]
      #
      # @return [Data]
      def self.read(s)
        payload_length = "\x00#{s[0..2]}".unpack1('N')
        # f_type = s[3].unpack1('C')
        padded = (s[4].unpack1('C') & 0b00001000).positive?
        end_stream = (s[4].unpack1('C') & 0b00000001).positive?
        stream_id = s[5..8].unpack1('N')
        if padded
          pad_length = s[9].unpack1('C')
          data_length = payload_length - pad_length - 1
          data = s[10...10 + data_length]
          padding = s[10 + data_length..]
        else
          data = s[9..]
          padding = nil
        end

        Data.new(end_stream, stream_id, data, padding)
      end
    end
  end
end
