module Biryani
  class HTTPRequest
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

  class HTTPRequestBuilder
    PSEUDO_HEADER_FIELDS = [':authority', ':method', ':path', ':scheme'].freeze
    Ractor.make_shareable(PSEUDO_HEADER_FIELDS)

    def initialize
      @h = {}
    end

    # @param name [String]
    # @param value [String]
    #
    # @return [nil, ConnectioError]
    # rubocop: disable Metrics/AbcSize
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/PerceivedComplexity
    def field(name, value)
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'field name has uppercase letter') if name.downcase != name
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'unknown pseudo-header field name') if name[0] == ':' && !PSEUDO_HEADER_FIELDS.include?(name)
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'appear pseudo-header fields after regular fields') if name[0] == ':' && @h.any? { |name_, _| name_[0] != ':' }
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'duplicated pseudo-header fields') if PSEUDO_HEADER_FIELDS.include?(name) && @h.key?(name)
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, "invalid `#{name}` field") if PSEUDO_HEADER_FIELDS.include?(name) && value.empty?
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'connection-specific field is forbidden') if name == 'connection'
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, '`TE` field has a value other than `trailers`') if name == 'te' && value != 'trailers'

      @h[name] = [] unless @h.key?(name)
      @h[name] << value

      nil
    end
    # rubocop: enable Metrics/AbcSize
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/PerceivedComplexity

    # @param arr [Array]
    #
    # @return [nil, ConnectioError]
    def fields(arr)
      arr.each do |name, value|
        err = field(name, value)
        return err unless err.nil?
      end

      nil
    end

    # @param s [String]
    #
    # @return [HTTPRequest]
    def build(s)
      h = @h.transform_values(&:dup)
      self.class.http_request(h, s)
    end

    # @param h [Hash<String, Array<String>>]
    # @param s [String]
    #
    # @return [HTTPRequest, ConnectionError]
    def self.http_request(h, s)
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'missing pseudo-header fields') unless PSEUDO_HEADER_FIELDS.all? { |x| h.key?(x) }
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid content-length') if h.key?('content-length') && !s.empty? && s.length != h['content-length'].to_i

      scheme = h[':scheme'][0]
      domain = h[':authority'][0]
      path = h[':path'][0]
      uri = URI("#{scheme}://#{domain}#{path}")
      method = h[':method'][0]
      h['cookie'] = [h['cookie'].join('; ')] if h.key?('cookie')
      HTTPRequest.new(method, uri, h, s)
    end
  end
end
