module Biryani
  module HTTP
    class Request
      attr_accessor :method, :uri, :fields, :content

      # @param method [String]
      # @param uri [URI]
      # @param fields [Hash<String, Array<String>>]
      # @param content [String]
      def initialize(method, uri, fields, content)
        @method = method
        @uri = uri
        @fields = fields
        @content = content
      end

      # @return [Array<String>, nil]
      def trailers
        # https://datatracker.ietf.org/doc/html/rfc9110#section-6.6.2-4
        keys = (@fields['trailer'] || []).flat_map { |x| x.split(',').map(&:strip) }
        @fields.slice(*keys)
      end
    end

    class RequestBuilder
      PSEUDO_HEADER_FIELDS = [':authority', ':method', ':path', ':scheme'].freeze
      Ractor.make_shareable(PSEUDO_HEADER_FIELDS)
      REQUIRED_PSEUDO_HEADER_FIELDS = [':method', ':path', ':scheme'].freeze
      Ractor.make_shareable(REQUIRED_PSEUDO_HEADER_FIELDS)

      def initialize
        @h = {}
      end

      # @param name [String]
      # @param value [String]
      #
      # @raise [Error::MalformedRequestError]
      # rubocop: disable Metrics/AbcSize
      # rubocop: disable Metrics/CyclomaticComplexity
      # rubocop: disable Metrics/PerceivedComplexity
      def field(name, value)
        raise Error::MalformedRequestError, 'field name has uppercase letter' if name.downcase != name
        raise Error::MalformedRequestError, 'unknown pseudo-header field name' if name[0] == ':' && !PSEUDO_HEADER_FIELDS.include?(name)
        raise Error::MalformedRequestError, 'appear pseudo-header fields after regular fields' if name[0] == ':' && @h.any? { |name_, _| name_[0] != ':' }
        raise Error::MalformedRequestError, 'duplicated pseudo-header fields' if PSEUDO_HEADER_FIELDS.include?(name) && @h.key?(name)
        raise Error::MalformedRequestError, "invalid `#{name}` field" if PSEUDO_HEADER_FIELDS.include?(name) && value.empty?
        raise Error::MalformedRequestError, 'connection-specific field is forbidden' if name == 'connection'
        raise Error::MalformedRequestError, '`TE` field has a value other than `trailers`' if name == 'te' && value != 'trailers'

        @h[name] = [] unless @h.key?(name)
        @h[name] << value
      end
      # rubocop: enable Metrics/AbcSize
      # rubocop: enable Metrics/CyclomaticComplexity
      # rubocop: enable Metrics/PerceivedComplexity

      # @param arr [Array]
      #
      # @raise [Error::MalformedRequestError]
      def fields(arr)
        arr.each do |name, value|
          field(name, value)
        end
      end

      # @param s [String]
      #
      # @return [Request]
      #
      # @raise [Error::MalformedRequestError]
      def build(s)
        # `Ractor.send(req, move: true)` moves entries in HPACK::DynamicTable; therefore, a `dup` call is required.
        h = @h.transform_values { |x| x.map(&:dup) }
        self.class.build(h, s)
      end

      # @param h [Hash<String, Array<String>>]
      # @param s [String]
      #
      # @return [Request]
      #
      # @raise [Error::MalformedRequestError]
      def self.build(h, s)
        # https://datatracker.ietf.org/doc/html/rfc9113#section-8.3.1-3
        raise Error::MalformedRequestError, 'missing pseudo-header fields' unless REQUIRED_PSEUDO_HEADER_FIELDS.all? { |x| h.key?(x) }
        raise Error::MalformedRequestError, 'invalid content-length' if h.key?('content-length') && !s.empty? && s.length != h['content-length'][0].to_i

        authority = authority(h)
        scheme = h[':scheme'][0]
        path = h[':path'][0]
        uri = URI("#{scheme}://#{authority}#{path}")
        method = h[':method'][0].upcase
        h['cookie'] = [h['cookie'].join('; ')] if h.key?('cookie')
        Request.new(method, uri, h.except(*PSEUDO_HEADER_FIELDS), s)
      end

      # @param h [Hash<String, Array<String>>]
      #
      # @return [String]
      #
      # @raise [Error::MalformedRequestError]
      # rubocop: disable Metrics/CyclomaticComplexity
      # rubocop: disable Metrics/PerceivedComplexity
      def self.authority(h)
        host = h['host']
        # https://datatracker.ietf.org/doc/html/rfc9110#section-5.3-3
        raise Error::MalformedRequestError, 'duplicated host fields' if !host.nil? && host.length > 1

        authority = h[':authority']&.first
        # https://datatracker.ietf.org/doc/html/rfc9113#section-8.3.1-2.3.3
        raise Error::MalformedRequestError, 'mismatched :authority and host fields' if !authority.nil? && !host.nil? && authority.downcase != host[0].downcase

        s = authority || host&.first
        # https://datatracker.ietf.org/doc/html/rfc9110#section-4.2.1-4
        # https://datatracker.ietf.org/doc/html/rfc9110#section-4.2.2-4
        raise Error::MalformedRequestError, 'missing :authority and host fields' if s.nil? || s.empty?

        s
      end
      # rubocop: enable Metrics/CyclomaticComplexity
      # rubocop: enable Metrics/PerceivedComplexity
    end
  end
end
