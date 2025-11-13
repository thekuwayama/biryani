require_relative 'dynamic_table'
require_relative 'fields'

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
        Fields.encode(fields, @dynamic_table)
      end
    end
  end
end
