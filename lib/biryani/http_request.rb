module Biryani
  class HTTPRequest
    attr_accessor :method, :uri, :fields, :content

    # @param method [String]
    # @param uri [URI]
    # @param fields [Hash<String, String>]
    # @param content [String]
    def initialize(method, uri, fields, content)
      @method = method
      @uri = uri
      @fields = fields
      @content = content
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
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/PerceivedComplexity
    def field(name, value)
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'field name has uppercase letter') if name.downcase != name
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'unknown pseudo-header field name') if name[0] == ':' && !PSEUDO_HEADER_FIELDS.include?(name)
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'appear pseudo-header fields after regular fields') if name[0] == ':' && @h.any? { |name_, _| name_[0] != ':' }
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'duplicated pseudo-header fields') if PSEUDO_HEADER_FIELDS.include?(name) && @h.key?(name)
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, "invalid `#{name}` field") if PSEUDO_HEADER_FIELDS.include?(name) && value.empty?
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'connection-specific field is forbidden') if name == 'connection'

      # TODO: trailers

      if name == 'cookie' && @h.key?('cookie')
        @h[name] += "; #{value}"
      else
        @h[name] = value
      end

      nil
    end
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
      self.class.http_request(@h, s)
    end

    # @param fields [Hash<String, String>]
    # @param s [String]
    #
    # @return [HTTPRequest, ConnectionError]
    def self.http_request(fields, s)
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'missing pseudo-header fields') unless PSEUDO_HEADER_FIELDS.all? { |x| fields.key?(x) }
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid content-length') if fields.key?('content-length') && !s.empty? && s.length != fields['content-length'].to_i

      uri = URI("#{fields[':scheme']}://#{fields[':authority']}#{fields[':path']}")
      HTTPRequest.new(fields[':method'], uri, fields.reject { |name, _| PSEUDO_HEADER_FIELDS.include?(name) }, s)
    end
  end
end
