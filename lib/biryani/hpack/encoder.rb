module Biryani
  module HPACK
    class Encoder
      # @param max_size_limit [Integer]
      def initialize(max_size_limit)
        @dynamic_table = DynamicTable.new(max_size_limit)
      end

      # @param fields [Array]
      #
      # @return [String]
      def encode(fields)
        Fields.encode(fields, @dynamic_table).force_encoding(Encoding::ASCII_8BIT)
      end

      # @param new_max_size_limit [Integer]
      def max_size_limit!(new_max_size_limit)
        @dynamic_table.max_size_limit!(new_max_size_limit)
      end
    end
  end
end
