require_relative 'huffman'
require_relative 'integer'

module Biryani
  module HPACK
    module String
      #   0   1   2   3   4   5   6   7
      # +---+---+---+---+---+---+---+---+
      # | H |    String Length (7+)     |
      # +---+---------------------------+
      # |  String Data (Length octets)  |
      # +-------------------------------+
      # https://datatracker.ietf.org/doc/html/rfc7541#section-5.2
      #
      # @param s [String]
      #
      # @return [String]
      def self.encode(s)
        bytes = Huffman.encode(s)
        bytes = s if bytes.bytesize > s.bytesize
        Integer.encode(bytes.length, 7, 0b10000000) + bytes
      end

      # @param s [String]
      #
      # @return [String]
      def self.decode(s)
        h = (s.getbyte(0) | 0b10000000).positive?
        len = Integer.decode(s.getbyte(0) & 127, 7)
        return Huffman.decode(s[1..len + 1]) if h

        s[1..len + 1] # TODO: return offset
      end
    end
  end
end
