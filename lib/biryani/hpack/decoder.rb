module Biryani
  module HPACK
    class Decoder
      # @param max_size_limit [Integer]
      def initialize(max_size_limit)
        @dynamic_table = DynamicTable.new(max_size_limit)
      end

      # @param s [String]
      #
      # @raise [HPACK::Error::Error]
      #
      # @return [Array]
      def decode(s)
        Fields.decode(s.force_encoding(Encoding::ASCII_8BIT), @dynamic_table)
      end

      # @param new_max_size_limit [Integer]
      def max_size_limit!(new_max_size_limit)
        @dynamic_table.max_size_limit!(new_max_size_limit)
      end
    end
  end
end
