module Biryani
  module HPACK
    module Field
      # https://datatracker.ietf.org/doc/html/rfc7541#appendix-A
      STATIC_TABLE = [
        [':authority',                  ''],
        [':method',                     'GET'],
        [':method',                     'POST'],
        [':path',                       '/'],
        [':path',                       '/index.html'],
        [':scheme',                     'http'],
        [':scheme',                     'https'],
        [':status',                     '200'],
        [':status',                     '204'],
        [':status',                     '206'],
        [':status',                     '304'],
        [':status',                     '400'],
        [':status',                     '404'],
        [':status',                     '500'],
        ['accept-charset',              ''],
        ['accept-encoding',             'gzip, deflate'],
        ['accept-language',             ''],
        ['accept-ranges',               ''],
        ['accept',                      ''],
        ['access-control-allow-origin', ''],
        ['age',                         ''],
        ['allow',                       ''],
        ['authorization',               ''],
        ['cache-control',               ''],
        ['content-disposition',         ''],
        ['content-encoding',            ''],
        ['content-language',            ''],
        ['content-length',              ''],
        ['content-location',            ''],
        ['content-range',               ''],
        ['content-type',                ''],
        ['cookie',                      ''],
        ['date',                        ''],
        ['etag',                        ''],
        ['expect',                      ''],
        ['expires',                     ''],
        ['from',                        ''],
        ['host',                        ''],
        ['if-match',                    ''],
        ['if-modified-since',           ''],
        ['if-none-match',               ''],
        ['if-range',                    ''],
        ['if-unmodified-since',         ''],
        ['last-modified',               ''],
        ['link',                        ''],
        ['location',                    ''],
        ['max-forwards',                ''],
        ['proxy-authenticate',          ''],
        ['proxy-authorization',         ''],
        ['range',                       ''],
        ['referer',                     ''],
        ['refresh',                     ''],
        ['retry-after',                 ''],
        ['server',                      ''],
        ['set-cookie',                  ''],
        ['strict-transport-security',   ''],
        ['transfer-encoding',           ''],
        ['user-agent',                  ''],
        ['vary',                        ''],
        ['via',                         ''],
        ['www-authenticate',            '']
      ].freeze

      private_constant :STATIC_TABLE

      def self.find(name, value)
        nv, i = STATIC_TABLE.each_with_index.find { |nv, _| nv.first == name }
        if nv.nil?
          None.new
        elsif nv[1] == value
          Some.new(i + 1, nil)
        else
          Some.new(i + 1, value)
        end

        # TODO: dynamic table
      end

      # @param name [String]
      # @param value [String]
      #
      # @return [String]
      def self.encode(name, value)
        case find(name, value)
        in Some(index, value) if value.nil?
          encode_indexed(index)
        in Some(index, value)
          encode_literal_value_incremental_indexing(index, value)
        in None
          encode_literal_field_incremental_indexing(name, value)
        end
      end

      #   0   1   2   3   4   5   6   7
      # +---+---+---+---+---+---+---+---+
      # | 1 |        Index (7+)         |
      # +---+---------------------------+
      # https://datatracker.ietf.org/doc/html/rfc7541#section-6.1
      #
      # @param index [Integer]
      #
      # @return [String]
      def self.encode_indexed(index)
        Integer.encode(index, 7, 0b10000000)
      end

      #   0   1   2   3   4   5   6   7
      # +---+---+---+---+---+---+---+---+
      # | 0 | 1 |      Index (6+)       |
      # +---+---+-----------------------+
      # | H |     Value Length (7+)     |
      # +---+---------------------------+
      # | Value String (Length octets)  |
      # +-------------------------------+
      # https://datatracker.ietf.org/doc/html/rfc7541#section-6.2.1
      #
      # @param index [Integer]
      # @param value [String]
      #
      # @return [String]
      def self.encode_literal_value_incremental_indexing(index, value)
        Integer.encode(index, 6, 0b01000000) + String.encode(value)
      end

      #   0   1   2   3   4   5   6   7
      # +---+---+---+---+---+---+---+---+
      # | 0 | 1 |           0           |
      # +---+---+-----------------------+
      # | H |     Name Length (7+)      |
      # +---+---------------------------+
      # |  Name String (Length octets)  |
      # +---+---------------------------+
      # | H |     Value Length (7+)     |
      # +---+---------------------------+
      # | Value String (Length octets)  |
      # +-------------------------------+
      # https://datatracker.ietf.org/doc/html/rfc7541#section-6.2.1
      #
      # @param name [String]
      # @param value [String]
      #
      # @return [String]
      def self.encode_literal_field_incremental_indexing(name, value)
        "\x40#{String.encode(name)}#{String.encode(value)}"
      end

      #   0   1   2   3   4   5   6   7
      # +---+---+---+---+---+---+---+---+
      # | 0 | 0 | 0 | 0 |  Index (4+)   |
      # +---+---+-----------------------+
      # | H |     Value Length (7+)     |
      # +---+---------------------------+
      # | Value String (Length octets)  |
      # +-------------------------------+
      # https://datatracker.ietf.org/doc/html/rfc7541#section-6.2.2
      #
      # @param index [Integer]
      # @param value [String]
      #
      # @return [String]
      def self.encode_literal_value_without_indexing(index, value)
        Integer.encode(index, 4, 0b00000000) + String.encode(value)
      end

      #   0   1   2   3   4   5   6   7
      # +---+---+---+---+---+---+---+---+
      # | 0 | 0 | 0 | 0 |       0       |
      # +---+---+-----------------------+
      # | H |     Name Length (7+)      |
      # +---+---------------------------+
      # |  Name String (Length octets)  |
      # +---+---------------------------+
      # | H |     Value Length (7+)     |
      # +---+---------------------------+
      # | Value String (Length octets)  |
      # +-------------------------------+
      # https://datatracker.ietf.org/doc/html/rfc7541#section-6.2.2
      #
      # @param index [Integer]
      # @param value [String]
      #
      # @return [String]
      def self.encode_literal_field_without_indexing(name, value)
        "\x00#{String.encode(name)}#{String.encode(value)}"
      end

      # TODO: Dynamic Table Size Update
    end
  end
end
