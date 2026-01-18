module Biryani
  class HTTPResponse
    FORBIDDEN_KEY_CHARS = (0x00..0x20).chain([0x3a]).chain(0x41..0x5a).chain(0x7f..0xff).to_a.freeze
    FORBIDDEN_VALUE_CHARS = [0x00, 0x0a, 0x0d].freeze

    attr_accessor :status, :fields, :content

    # @param status [Integer]
    # @param fields [Hash]
    # @param content [String, nil]
    def initialize(status, fields, content)
      @status = status
      @fields = fields
      @content = content
    end

    # @raise [InvalidHTTPResponseError]
    # rubocop: disable Metrics/CyclomaticComplexity
    def validate
      raise Error::InvalidHTTPResponseError, 'invalid HTTP status' if @status < 100 || @status >= 600
      raise Error::InvalidHTTPResponseError, 'HTTP field name contains invalid characters' if (@fields.keys.join.downcase.bytes.uniq & FORBIDDEN_KEY_CHARS).any?
      raise Error::InvalidHTTPResponseError, 'HTTP field value contains NUL, LF or CR' if (@fields.values.join.bytes.uniq & FORBIDDEN_VALUE_CHARS).any?
      raise Error::InvalidHTTPResponseError, 'HTTP field value starts/ends with SP or HTAB' if @fields.values.filter { |s| s.start_with?("\t", ' ') || s.end_with?("\t", ' ') }.any?
    end
    # rubocop: enable Metrics/CyclomaticComplexity

    def self.default
      HTTPResponse.new(0, {}, nil)
    end

    def self.internal_server_error
      HTTPResponse.new(500, {}, 'Internal Server Error')
    end
  end

  class HTTPResponseParser
    # @param res [HTTPResponse]
    def initialize(res)
      @res = res
    end

    # @return [Array]
    def fields
      fields = [[':status', @res.status.to_s]]
      @res.fields.each do |name, value|
        fields << [name.to_s.downcase, value.to_s]
      end

      fields
    end

    # @return [String]
    def content
      @res.content
    end

    # @param encoder [Encoder]
    #
    # @return [String] fragment
    # @return [String] data
    def parse(encoder)
      [encoder.encode(fields), content]
    end
  end
end
