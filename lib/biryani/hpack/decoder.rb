require_relative 'dynamic_table'
require_relative 'fields'

module Biryani
  module HPACK
    class Decoder
      # @param dynamic_table_limit [Integer]
      def initialize(dynamic_table_limit)
        @dynamic_table = DynamicTable.new(dynamic_table_limit)
      end

      # @param bytes [String]
      #
      # @return [Array]
      def decode(bytes)
        Fields.decode(bytes, @dynamic_table)
      end
    end
  end
end
