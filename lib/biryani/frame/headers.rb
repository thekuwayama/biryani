module Biryani
  module Frame
    class Headers
      attr_reader :f_type, :stream_id, :stream_dependency, :weight, :fragment, :padding

      # @param end_headers [Boolean]
      # @param end_stream [Boolean]
      # @param stream_id [Integer]
      # @param stream_dependency [Integer, nil]
      # @param weight [Integer, nil]
      # @param fragment [String]
      # @param padding [String, nil]
      def initialize(end_headers, end_stream, stream_id, stream_dependency, weight, fragment, padding)
        @f_type = FrameType::HEADERS
        @end_headers = end_headers
        @end_stream = end_stream
        @stream_id = stream_id
        @stream_dependency = stream_dependency
        @weight = weight
        @fragment = fragment
        @padding = padding
      end

      # @return [Boolean]
      def priority?
        !@stream_dependency.nil? && !@weight.nil?
      end

      # @return [Boolean]
      def padded?
        !@padding.nil?
      end

      # @return [Boolean]
      def end_headers?
        @end_headers
      end

      # @return [Boolean]
      def end_stream?
        @end_stream
      end

      # @return [Integer]
      def length
        @fragment.bytesize + (padded? ? 1 + @padding.bytesize : 0) + (priority? ? 5 : 0)
      end

      # @return [String]
      def to_binary_s
        payload_length = length
        flags = Frame.to_flags(priority: priority?, padded: padded?, end_headers: end_headers?, end_stream: end_stream?)
        pad_length = padded? ? @padding.bytesize.chr : ''
        stream_dependency_weight = priority? ? [@stream_dependency, @weight].pack('NC') : ''
        padding = @padding || ''

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + pad_length + stream_dependency_weight + @fragment + padding
      end

      # @param s [String]
      # @param flags [Integer]
      # @param stream_id [Integer]
      #
      # @return [Headers]
      # rubocop: disable Metrics/AbcSize
      # rubocop: disable Metrics/CyclomaticComplexity
      # rubocop: disable Metrics/MethodLength
      # rubocop: disable Metrics/PerceivedComplexity
      def self.read(s, flags, stream_id)
        priority = Frame.read_priority(flags)
        padded = Frame.read_padded(flags)
        end_headers = Frame.read_end_headers(flags)
        end_stream = Frame.read_end_stream(flags)

        if priority && padded
          io = IO::Buffer.for(s)
          pad_length, stream_dependency, weight = io.get_values(%i[U8 U32 U8], 0)
          fragment_length = s.bytesize - pad_length - 6
          # exclusive = (stream_dependency / 2**31).positive?
          stream_dependency %= 2**31
          return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'cannot depend on itself') if stream_dependency == stream_id

          fragment = io.get_string(6, fragment_length)
          padding = io.get_string(6 + fragment_length)
          return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'invalid frame') if padding.bytesize != pad_length
        elsif priority
          io = IO::Buffer.for(s)
          stream_dependency, weight = io.get_values(%i[U32 U8], 0)
          # exclusive = (stream_dependency / 2**31).positive?
          stream_dependency %= 2**31
          return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'cannot depend on itself') if stream_dependency == stream_id

          fragment = io.get_string(5)
          return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'invalid frame') if fragment.bytesize + 5 != s.bytesize
        elsif padded
          io = IO::Buffer.for(s)
          pad_length = io.get_value(:U8, 0)
          fragment_length = s.bytesize - pad_length - 1
          fragment = io.get_string(1, fragment_length)
          padding = io.get_string(1 + fragment_length)
          return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid frame') if pad_length >= s.bytesize
          return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid frame') if padding.bytesize != pad_length
        else
          fragment = s
        end

        Headers.new(end_headers, end_stream, stream_id, stream_dependency, weight, fragment, padding)
      end
      # rubocop: enable Metrics/AbcSize
      # rubocop: enable Metrics/CyclomaticComplexity
      # rubocop: enable Metrics/MethodLength
      # rubocop: enable Metrics/PerceivedComplexity
    end
  end
end
