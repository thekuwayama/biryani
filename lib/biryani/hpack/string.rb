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
        res = Huffman.encode(s)
        res = s if res.bytesize > s.bytesize
        Integer.encode(res.bytesize, 7, 0b10000000) + res
      end

      # @param s [String]
      # @param cursor [Integer]
      #
      # @return [String]
      # @return [Integer]
      def self.decode(s, cursor)
        h = (s.getbyte(cursor) | 0b10000000).positive?
        len, c = Integer.decode(s, 7, cursor)
        return [Huffman.decode(s[c...c + len]), c + len] if h

        [s[c...c + len], c + len]
      end
    end
  end
end
