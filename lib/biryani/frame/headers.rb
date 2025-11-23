module Biryani
  module Frame
    class Headers
      attr_reader :f_type, :end_headers, :end_stream, :stream_id, :stream_dependency, :weight, :fragment, :padding

      # @params end_headers [Boolean]
      # @params end_stream [Boolean]
      # @params stream_id [Integer]
      # @params stream_dependency [Integer, nil]
      # @params weight [Integer, nil]
      # @params fragment [String]
      # @params padding [String, nil]
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
      def exclusive?
        !@stream_dependency.nil? && !@weight.nil?
      end

      # @return [String]
      # rubocop: disable Metrics/AbcSize
      # rubocop: disable Metrics/CyclomaticComplexity
      # rubocop: disable Metrics/PerceivedComplexity
      def to_binary_s
        payload_length = [@fragment.bytesize + (padded? ? 1 + @padding.bytesize : 0) + (priority? ? 5 : 0)].pack('N1')[1..]
        f_type = @f_type.chr
        flags = ((priority? ? 32 : 0) + (padded? ? 8 : 0) + (@end_headers ? 4 : 0) + (@end_stream ? 1 : 0)).chr
        stream_id = [@stream_id].pack('N1')
        pad_length = padded? ? @padding.bytesize.chr : ''
        stream_dependency = if priority?
                              [(exclusive? ? 2**31 : 0) | @stream_dependency].pack('N1')
                            else
                              ''
                            end
        weight = priority? ? @weight.chr : ''
        padding = @padding || ''

        payload_length + f_type + flags + stream_id + pad_length + stream_dependency + weight + @fragment + padding
      end
      # rubocop: enable Metrics/AbcSize
      # rubocop: enable Metrics/CyclomaticComplexity
      # rubocop: enable Metrics/PerceivedComplexity

      # @params s [String]
      #
      # @return [Headers]
      # rubocop: disable Metrics/AbcSize
      def self.read(s)
        payload_length = "\x00#{s[0..2]}".unpack1('N')
        # f_type = s[3].unpack1('C')
        priority = (s[4].unpack1('C') & 0b00100000).positive?
        padded = (s[4].unpack1('C') & 0b00001000).positive?
        end_headers = (s[4].unpack1('C') & 0b00000100).positive?
        end_stream = (s[4].unpack1('C') & 0b00000001).positive?
        stream_id = s[5..8].unpack1('N')

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
