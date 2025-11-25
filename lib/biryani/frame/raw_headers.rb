module Biryani
  module Frame
    class RawHeaders
      attr_reader :f_type, :stream_id, :fields

      # @param end_headers [Boolean]
      # @param end_stream [Boolean]
      # @param stream_id [Integer]
      # @param stream_dependency [Integer, nil]
      # @param weight [Integer, nil]
      # @param fields [Array]
      # @param padding [String, nil]
      # rubocop: disable Metrics/ParameterLists
      def initialize(end_headers, end_stream, stream_id, stream_dependency, weight, fields, padding)
        @f_type = FrameType::HEADERS
        @end_headers = end_headers
        @end_stream = end_stream
        @stream_id = stream_id
        @stream_dependency = stream_dependency
        @weight = weight
        @fields = fields
        @padding = padding
      end
      # rubocop: enable Metrics/ParameterLists

      # @return [Boolean]
      def end_stream?
        @end_stream
      end

      # @param encoder [Encoder]
      #
      # @return [Headers]
      def encode(encoder)
        fragment = encoder.encode(@fields)

        Headers.new(@end_headers, @end_stream, @stream_id, @stream_dependency, @weight, fragment, @padding)
      end
    end
  end
end
