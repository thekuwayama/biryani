module Biryani
  class FieldsBucket
    def initialize
      @fields = {}
    end

    # @param name [String]
    # @param value [String]
    def []=(name, value)
      # TODO: return ConnectionError or StreamError

      # TODO: cookie
      @fields[name] = value
    end

    alias store []=

    # @param h [Hash<String, String>]
    def merge!(h)
      h.each do |name, value|
        store(name, value)
      end
    end

    # @param _content [String]
    #
    # @return [Net::HTTPRequest]
    def http_request(_content)
      # TODO
    end
  end
end
