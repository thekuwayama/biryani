module Biryani
  module HPACK
    class Encoder
      # @param dynamic_table_limit [Integer]
      def initialize(dynamic_table_limit)
        @dynamic_table = DynamicTable.new(dynamic_table_limit)
      end

      # @param fields [Array]
      #
      # @return [String]
      def encode(fields)
        Fields.encode(fields, @dynamic_table).force_encoding(Encoding::ASCII_8BIT)
      end

      # @param new_limit [Integer]
      def limit!(new_limit)
        @dynamic_table.limit!(new_limit)
      end
    end
  end
end
