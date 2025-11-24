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
      # rubocop: disable Metrics/ParameterLists
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
      # rubocop: enable Metrics/ParameterLists

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

      # @return [Boolean]
      def exclusive?
        !@stream_dependency.nil? && !@weight.nil?
      end

      # @return [String]
      # rubocop: disable Metrics/CyclomaticComplexity
      # rubocop: disable Metrics/PerceivedComplexity
      def to_binary_s
        payload_length = @fragment.bytesize + (padded? ? 1 + @padding.bytesize : 0) + (priority? ? 5 : 0)
        flags = Frame.to_flags(priority: priority?, padded: padded?, end_headers: end_headers?, end_stream: end_stream?)
        pad_length = padded? ? @padding.bytesize.chr : ''
        stream_dependency = if priority?
                              [(exclusive? ? 2**31 : 0) | @stream_dependency].pack('N1')
                            else
                              ''
                            end
        weight = priority? ? @weight.chr : ''
        padding = @padding || ''

        Frame.to_binary_s_header(payload_length, @f_type, flags, @stream_id) + pad_length + stream_dependency + weight + @fragment + padding
      end
      # rubocop: enable Metrics/CyclomaticComplexity
      # rubocop: enable Metrics/PerceivedComplexity

      # @param s [String]
      #
      # @return [Headers]
      # rubocop: disable Metrics/AbcSize
      def self.read(s)
        payload_length, _, uint8, stream_id = Frame.read_header(s)
        priority = Frame.read_priority(uint8)
        padded = Frame.read_padded(uint8)
        end_headers = Frame.read_end_headers(uint8)
        end_stream = Frame.read_end_stream(uint8)

        if priority && padded
          fragment_length = payload_length
          pad_length = s[9].unpack1('C')
          fragment_length -= pad_length + 6
          # exclusive = (s[10..13].unpack1('N') / 2**31).positive?
          stream_dependency = s[10..13].unpack1('N') % 2**31
          weight = s[14].unpack1('C')
          fragment = s[15...15 + fragment_length]
          padding = s[15 + fragment_length..]
        elsif priority
          # exclusive = (s[9..12].unpack1('N') / 2**31).positive?
          stream_dependency = s[9..12].unpack1('N') % 2**31
          weight = s[13].unpack1('C')
          fragment = s[14..]
        elsif padded
          fragment_length = payload_length
          pad_length = s[9].unpack1('C')
          fragment_length -= pad_length
          fragment = s[10...10 + fragment_length]
          padding = s[10 + fragment_length..]
        else
          fragment = s[9..]
          padding = nil
        end

        Headers.new(end_headers, end_stream, stream_id, stream_dependency, weight, fragment, padding)
      end
      # rubocop: enable Metrics/AbcSize
    end
  end
end
