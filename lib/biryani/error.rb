module Biryani
  module Error
    # Generic error, common for all classes under Biryani::Error module.
    class Error < StandardError; end

    class InvalidHTTPResponseError < Error; end
  end
end
