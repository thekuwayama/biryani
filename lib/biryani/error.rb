module Biryani
  module Error
    # Generic error, common for all classes under Biryani::Error module.
    class Error < StandardError; end

    class HuffmanDecodeError < Error; end

    class HPACKDecodeError < Error; end

    class FrameReadError < Error; end
  end
end
