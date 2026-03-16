module Biryani
  module HTTP
    module Error
      # Generic error, common for all classes under Biryani::HTTP::Error module.
      class Error < StandardError; end

      class InvalidHTTPResponseError < Error; end
    end
  end
end
