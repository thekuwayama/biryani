require_relative 'field'

module Biryani
  module HPACK
    module Fields
      # @param fields [Array]
      # @param dynamic_table [DynamicTable]
      #
      # @return [String]
      def self.encode(fields, dynamic_table)
        fields.each_with_object(''.b) { |nv, acc| acc << Field.encode(nv[0].to_s, nv[1].to_s, dynamic_table) }
      end
    end
  end
end
