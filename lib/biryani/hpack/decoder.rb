module Biryani
  module HPACK
    class Decoder
      # @param dynamic_table_limit [Integer]
      def initialize(dynamic_table_limit)
        @dynamic_table = DynamicTable.new(dynamic_table_limit)
      end

      # @param s [String]
      #
      # @return [Array]
      def decode(s)
        Fields.decode(s.force_encoding(Encoding::ASCII_8BIT), @dynamic_table)
      end

      # @param new_limit [Integer]
      def limit!(new_limit)
        @dynamic_table.limit!(new_limit)
      end
    end
  end
end
