module Biryani
  class FieldsBucket
    PSEUDO_HEADER_FIELDS = [':authority', ':method', ':path', ':scheme'].freeze
    Ractor.make_shareable(PSEUDO_HEADER_FIELDS)

    def initialize
      @fields = {}
    end

    # @param name [String]
    # @param value [String]
    #
    # @return [nil, ConnectioError]
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/PerceivedComplexity
    def store(name, value)
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'field name has uppercase letter') if name.downcase != name
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'unknown pseudo-header field name') if name[0] == ':' && !PSEUDO_HEADER_FIELDS.include?(name)
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid :path field') if name == ':path' && value.empty?
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'connection-specific field is prohibited') if name == 'connection-specific'
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'duplicated pseudo-header fields') if PSEUDO_HEADER_FIELDS.include?(name) && @fields.key?(name)

      if name == 'cookie' && @fields.key?('cookie')
        @fields[name] += "; #{value}"
      else
        @fields[name] = value
      end

      nil
    end
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/PerceivedComplexity

    # @param fields [Array]
    #
    # @return [nil, ConnectioError]
    def merge!(fields)
      fields.each do |name, value|
        err = store(name, value)
        return err unless err.nil?
      end
    end

    # @param content [StringIO]
    #
    # @return [Net::HTTPRequest]
    def http_request(content)
      self.class.http_request(@fields, content.string)
    end

    # @param fields [Hash<String, String>]
    # @param s [String]
    #
    # @return [Net::HTTPRequest, ConnectionError]
    def self.http_request(fields, s)
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'missing pseudo-header fields') unless PSEUDO_HEADER_FIELDS.all? { |x| fields.key?(x) }
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid content-length') if s.length != fields['content-length'].to_i

      uri = URI("#{fields[':scheme']}://#{fields[':authority']}#{fields[':path']}")
      request = Net::HTTP.const_get(fields[':method'].capitalize).new(uri, fields.reject { |name, _| PSEUDO_HEADER_FIELDS.include?(name) })
      request.body = s
      request
    end
  end
end
