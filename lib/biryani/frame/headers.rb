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
      #
      # @return [Headers]
      # rubocop: disable Metrics/AbcSize
      # rubocop: disable Metrics/CyclomaticComplexity
      # rubocop: disable Metrics/PerceivedComplexity
      def self.read(s)
        payload_length, _, flags, stream_id = Frame.read_header(s)
        return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid frame') if s[9..].bytesize != payload_length

        priority = Frame.read_priority(flags)
        padded = Frame.read_padded(flags)
        end_headers = Frame.read_end_headers(flags)
        end_stream = Frame.read_end_stream(flags)

        if priority && padded
          pad_length, stream_dependency, weight = s[9..14].unpack('CNC')
          fragment_length = payload_length - pad_length - 6
          # exclusive = (stream_dependency / 2**31).positive?
          stream_dependency %= 2**31
          fragment = s[15...15 + fragment_length]
          padding = s[15 + fragment_length..]
          return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'invalid frame') if padding.bytesize != pad_length
        elsif priority
          stream_dependency, weight = s[9..13].unpack('NC')
          # exclusive = (stream_dependency / 2**31).positive?
          stream_dependency %= 2**31
          fragment = s[14..]
          return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'invalid frame') if fragment.bytesize + 5 != payload_length
        elsif padded
          pad_length = s[9].unpack1('C')
          fragment_length = payload_length - pad_length - 1
          fragment = s[10...10 + fragment_length]
          padding = s[10 + fragment_length..]
          return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid frame') if pad_length >= payload_length
          return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid frame') if padding.bytesize != pad_length
        else
          fragment = s[9..]
          return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid frame') if fragment.bytesize != payload_length
        end

        Headers.new(end_headers, end_stream, stream_id, stream_dependency, weight, fragment, padding)
      end
      # rubocop: enable Metrics/AbcSize
      # rubocop: enable Metrics/CyclomaticComplexity
      # rubocop: enable Metrics/PerceivedComplexity
    end
  end
end
