module Biryani
  module HPACK
    module Integer
      # if I < 2^N - 1, encode I on N bits
      # else
      #     encode (2^N - 1) on N bits
      #     I = I - (2^N - 1)
      #     while I >= 128
      #          encode (I % 128 + 128) on 8 bits
      #          I = I / 128
      #     encode I on 8 bits
      # decode I from the next N bits
      # if I < 2^N - 1, return I
      # else
      #     M = 0
      #     repeat
      #         B = next octet
      #         I = I + (B & 127) * 2^M
      #         M = M + 7
      #     while B & 128 == 128
      #     return I
      # https://datatracker.ietf.org/doc/html/rfc7541#section-5.1
      #
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
        h = s.getbyte(cursor)
        return [h & limit, cursor + 1] if (h & limit) != limit

        res = limit
        s[cursor + 1..].each_byte.each_with_index.each do |byte, i|
          res += (byte & 127) * 2**(i * 7)
          cursor += 1

          break if (byte & 128).zero?
        end

        [res, cursor + 1]
      end
    end
  end
end
