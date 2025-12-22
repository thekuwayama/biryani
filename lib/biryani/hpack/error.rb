module Biryani
  module HPACK
    module Error
      # Generic error, common for all classes under Biryani::HPACK::Error module.
      class Error < StandardError; end

      class HuffmanDecodeError < Error; end

      class HPACKDecodeError < Error; end
    end
  end
end
