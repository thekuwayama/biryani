require_relative 'dynamic_table'
require_relative 'integer'
require_relative 'option'
require_relative 'string'

module Biryani
  module HPACK
    module Field
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

      # @param name [String]
      # @param value [String]
      # @param dynamic_table [DynamicTable]
      #
      # @return [String]
      def self.encode(name, value, dynamic_table)
        case find(name, value, dynamic_table)
        in Some(index, v) if v.nil?
          bytes = encode_indexed(index)
        in Some(index, v)
          bytes = encode_literal_value(index, v)
          dynamic_table.store(name, v)
        in None
          bytes = encode_literal_field(name, value)
          dynamic_table.store(name, value)
        end

        bytes
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

      # TODO: Dynamic Table Size Update
    end
  end
end
