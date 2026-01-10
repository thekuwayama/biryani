module Biryani
  module HPACK
    # rubocop: disable Metrics/ModuleLength
    module Field
      # @param name [String]
      # @param value [String]
      # @param dynamic_table [DynamicTable]
      #
      # @return [String]
      def self.encode(name, value, dynamic_table)
        case find(name, value, dynamic_table)
        in Some(index, v) if v.nil?
          res = encode_indexed(index)
        in Some(index, v)
          res = encode_literal_value(index, v)
          dynamic_table.store(name, v)
        in None
          res = encode_literal_field(name, value)
          dynamic_table.store(name, value)
        end

        res
      end

      # @param name [String]
      # @param value [String]
      # @param dynamic_table [DynamicTable]
      #
      # @return [Some, None]
      # rubocop: disable Metrics/CyclomaticComplexity
      def self.find(name, value, dynamic_table)
        found, i = STATIC_TABLE.each_with_index.find { |nv, _| nv[0] == name && nv[1] == value }
        return Some.new(i + 1, nil) unless found.nil?

        found, i = dynamic_table.find_field(name, value)
        return Some.new(i + 1 + STATIC_TABLE_SIZE, nil) unless found.nil?

        found, i = STATIC_TABLE.each_with_index.find { |nv, _| nv[0] == name }
        return Some.new(i + 1, value) unless found.nil?

        found, i = dynamic_table.find_name(name)
        return Some.new(i + 1 + STATIC_TABLE_SIZE, value) unless found.nil?

        None.new
      end
      # rubocop: enable Metrics/CyclomaticComplexity

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
      def self.encode_literal_value(index, value)
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
      def self.encode_literal_field(name, value)
        "\x40#{String.encode(name)}#{String.encode(value)}"
      end

      # @param io [IO::Buffer]
      # @param cursor [Integer]
      # @param dynamic_table [DynamicTable]
      #
      # @return [Array]
      # @return [Integer]
      # rubocop: disable Metrics/CyclomaticComplexity
      # rubocop: disable Metrics/PerceivedComplexity
      def self.decode(io, cursor, dynamic_table)
        byte = io.get_value(:U8, cursor)
        if (byte & 0b10000000).positive?
          decode_indexed(io, cursor, dynamic_table)
        elsif byte == 0b01000000
          decode_literal_field_incremental_indexing(io, cursor, dynamic_table)
        elsif (byte & 0b01000000).positive?
          decode_literal_value_incremental_indexing(io, cursor, dynamic_table)
        elsif (byte & 0b00100000).positive?
          decode_dynamic_table_size_update(io, cursor, dynamic_table)
        elsif byte == 0b00010000
          decode_literal_field_never_indexed(io, cursor)
        elsif (byte & 0b00010000).positive?
          decode_literal_value_never_indexed(io, cursor, dynamic_table)
        elsif byte.zero?
          decode_literal_field_without_indexing(io, cursor)
        elsif (byte & 0b11110000).zero?
          decode_literal_value_without_indexing(io, cursor, dynamic_table)
        else
          raise 'unreachable'
        end
      end
      # rubocop: enable Metrics/CyclomaticComplexity
      # rubocop: enable Metrics/PerceivedComplexity

      #   0   1   2   3   4   5   6   7
      # +---+---+---+---+---+---+---+---+
      # | 1 |        Index (7+)         |
      # +---+---------------------------+
      # https://datatracker.ietf.org/doc/html/rfc7541#section-6.1
      #
      # @param io [IO::Buffer]
      # @param cursor [Integer]
      # @param dynamic_table [DynamicTable]
      #
      # @return [Array]
      # @return [Integer]
      def self.decode_indexed(io, cursor, dynamic_table)
        index, c = Integer.decode(io, 7, cursor)
        raise Error::HPACKDecodeError if index.zero?
        raise Error::HPACKDecodeError if index > STATIC_TABLE_SIZE + dynamic_table.count_entries

        field = if index <= STATIC_TABLE_SIZE
                  STATIC_TABLE[index - 1]
                else
                  dynamic_table[index - 1 - STATIC_TABLE_SIZE]
                end

        [field, c]
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
      # @param io [IO::Buffer]
      # @param cursor [Integer]
      # @param dynamic_table [DynamicTable]
      #
      # @return [Array]
      # @return [Integer]
      def self.decode_literal_field_incremental_indexing(io, cursor, dynamic_table)
        name, c = String.decode(io, cursor + 1)
        value, c = String.decode(io, c)
        dynamic_table.store(name, value)

        [[name, value], c]
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
      # @param io [IO::Buffer]
      # @param cursor [Integer]
      # @param dynamic_table [DynamicTable]
      #
      # @return [Array]
      # @return [Integer]
      def self.decode_literal_value_incremental_indexing(io, cursor, dynamic_table)
        index, c = Integer.decode(io, 6, cursor)
        raise Error::HPACKDecodeError if index.zero?
        raise Error::HPACKDecodeError if index > STATIC_TABLE_SIZE + dynamic_table.count_entries

        name = if index <= STATIC_TABLE_SIZE
                 STATIC_TABLE[index - 1][0]
               else
                 dynamic_table[index - 1 - STATIC_TABLE_SIZE][0]
               end
        value, c = String.decode(io, c)
        dynamic_table.store(name, value)

        [[name, value], c]
      end

      #   0   1   2   3   4   5   6   7
      # +---+---+---+---+---+---+---+---+
      # | 0 | 0 | 1 |   Max size (5+)   |
      # +---+---------------------------+
      # https://datatracker.ietf.org/doc/html/rfc7541#section-6.3
      #
      # @param io [IO::Buffer]
      # @param cursor [Integer]
      # @param dynamic_table [DynamicTable]
      #
      # @return [nil]
      # @return [Integer]
      def self.decode_dynamic_table_size_update(io, cursor, dynamic_table)
        raise Error::HPACKDecodeError unless cursor.zero? || (io.get_value(:U8, 0) & 0b00100000).positive? && Integer.decode(io, 5, 0)[1] == cursor

        max_size, c = Integer.decode(io, 5, cursor)
        raise Error::HPACKDecodeError if max_size > dynamic_table.limit

        dynamic_table.chomp!(max_size)
        [nil, c]
      end

      #   0   1   2   3   4   5   6   7
      # +---+---+---+---+---+---+---+---+
      # | 0 | 0 | 0 | 1 |       0       |
      # +---+---+-----------------------+
      # | H |     Name Length (7+)      |
      # +---+---------------------------+
      # |  Name String (Length octets)  |
      # +---+---------------------------+
      # | H |     Value Length (7+)     |
      # +---+---------------------------+
      # | Value String (Length octets)  |
      # +-------------------------------+
      # https://datatracker.ietf.org/doc/html/rfc7541#section-6.2.3
      #
      # @param io [IO::Buffer]
      # @param cursor [Integer]
      #
      # @return [Array]
      # @return [Integer]
      def self.decode_literal_field_never_indexed(io, cursor)
        name, c = String.decode(io, cursor + 1)
        value, c = String.decode(io, c)

        [[name, value], c]
      end

      #   0   1   2   3   4   5   6   7
      # +---+---+---+---+---+---+---+---+
      # | 0 | 0 | 0 | 1 |  Index (4+)   |
      # +---+---+-----------------------+
      # | H |     Value Length (7+)     |
      # +---+---------------------------+
      # | Value String (Length octets)  |
      # +-------------------------------+
      # https://datatracker.ietf.org/doc/html/rfc7541#section-6.2.3
      #
      # @param io [IO::Buffer]
      # @param cursor [Integer]
      # @param dynamic_table [DynamicTable]
      #
      # @return [Array]
      # @return [Integer]
      def self.decode_literal_value_never_indexed(io, cursor, dynamic_table)
        index, c = Integer.decode(io, 4, cursor)
        raise Error::HPACKDecodeError if index.zero?
        raise Error::HPACKDecodeError if index > STATIC_TABLE_SIZE + dynamic_table.count_entries

        name = if index <= STATIC_TABLE_SIZE
                 STATIC_TABLE[index - 1][0]
               else
                 dynamic_table[index - 1 - STATIC_TABLE_SIZE][0]
               end
        value, c = String.decode(io, c)

        [[name, value], c]
      end

      #   0   1   2   3   4   5   6   7
      # +---+---+---+---+---+---+---+---+
      # | 0 | 0 | 0 | 1 |       0       |
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
      # @param io [IO::Buffer]
      # @param cursor [Integer]
      #
      # @return [Array]
      # @return [Integer]
      def self.decode_literal_field_without_indexing(io, cursor)
        name, c = String.decode(io, cursor + 1)
        value, c = String.decode(io, c)

        [[name, value], c]
      end

      #   0   1   2   3   4   5   6   7
      # +---+---+---+---+---+---+---+---+
      # | 0 | 0 | 0 | 0 |  Index (4+)   |
      # +---+---+-----------------------+
      # | H |     Value Length (7+)     |
      # +---+---------------------------+
      # | Value String (Length octets)  |
      # +-------------------------------+
      #
      # @param io [IO::Buffer]
      # @param cursor [Integer]
      # @param dynamic_table [DynamicTable]
      #
      # @return [Array]
      # @return [Integer]
      def self.decode_literal_value_without_indexing(io, cursor, dynamic_table)
        index, c = Integer.decode(io, 4, cursor)
        raise Error::HPACKDecodeError if index.zero?
        raise Error::HPACKDecodeError if index > STATIC_TABLE_SIZE + dynamic_table.count_entries

        name = if index <= STATIC_TABLE_SIZE
                 STATIC_TABLE[index - 1][0]
               else
                 dynamic_table[index - 1 - STATIC_TABLE_SIZE][0]
               end
        value, c = String.decode(io, c)

        [[name, value], c]
      end
    end
    # rubocop: enable Metrics/ModuleLength
  end
end
