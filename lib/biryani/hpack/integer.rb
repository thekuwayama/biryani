module Biryani
  module HPACK
    module Integer
      # @param i [Integer]
      # @param n [Integer]
      # @param mask [Integer]
      #
      # @return [Array]
      def self.encode(i, n, mask)
        limit = (1 << n) - 1
        return [i | mask].pack('C*') if i < limit

        bytes = [limit | mask]
        i -= limit
        while i > 128
          bytes << i % 128 + 128
          i /= 128
        end
        bytes << i
        bytes.pack('C*')
      end

      # @param s [String]
      # @param cursor [Integer]
      # @param n [Integer]
      #
      # @return [Integer]
      # @return [Integer]
      def self.decode(s, n, cursor)
        limit = (1 << n) - 1
        return [s.getbyte(cursor), cursor + 1] if s.getbyte(cursor) & limit != limit

        i = limit
        m = 0
        s[1..].each_byte.each do |byte|
          i += (byte & 127) * 2**m
          m += 7
          cursor += 1

          break if (byte & 128).zero?
        end

        [i, cursor + 1]
      end
    end
  end
end
