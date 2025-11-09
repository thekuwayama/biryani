module Biryani
  module HPACK
    module String
      # @param s [String]
      #
      # @return [String]
      def self.encode(s)
        bytes = Huffman.encode(s)
        bytes = s if res.bytesize > s.bytesize
        (Integer.encode(res.length, 7) & 128) + bytes
      end

      # @param s [String]
      #
      # @return [String]
      def self.decode(s)
        h = (s.getbyte(0) & 128).positive?
        len = Integer.decode(s.getbyte(0) & 127, 7)
        return Huffman.decode(s[1..len + 1]) if h

        s[1..len + 1] # TODO: return offset
      end
    end
  end
end
