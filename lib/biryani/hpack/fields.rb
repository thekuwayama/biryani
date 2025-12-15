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

      # @param s [String]
      # @param dynamic_table [DynamicTable]
      #
      # @return [Array]
      def self.decode(s, dynamic_table)
        cursor = 0
        fields = []
        while cursor < s.bytesize
          field, cursor = Field.decode(s, cursor, dynamic_table)
          fields << field unless field.nil?
        end

        fields
      end
    end
  end
end
