module Biryani
  class HTTPResponse
    attr_accessor :status, :fields, :content

    # @param status [Integer]
    # @param fields [Hash]
    # @param content [String]
    def initialize(status, fields, content)
      @status = status
      @fields = fields
      @content = content
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
        # TODO: validate fields
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
