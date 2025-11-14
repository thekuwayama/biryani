require_relative 'dynamic_table'
require_relative 'fields'

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
        Fields.decode(s, @dynamic_table)
      end
    end
  end
end
