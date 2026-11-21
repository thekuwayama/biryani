module Biryani
  module HPACK
    class Encoder
      # @param dynamic_table_limit [Integer]
      def initialize(dynamic_table_limit)
        @dynamic_table = DynamicTable.new(dynamic_table_limit)
        @signaled_limit = dynamic_table_limit
        @min_limit = nil
      end

      # @param fields [Array]
      #
      # @return [String]
      def encode(fields)
        (dynamic_table_size_update + Fields.encode(fields, @dynamic_table)).force_encoding(Encoding::ASCII_8BIT)
      end

      # @param new_limit [Integer]
      def limit!(new_limit)
        @dynamic_table.limit!(new_limit)
        @min_limit = [@min_limit || new_limit, new_limit].min
      end

      private

      # https://datatracker.ietf.org/doc/html/rfc7541#section-4.2
      #
      # @return [String]
      def dynamic_table_size_update
        return ''.b if @min_limit.nil?

        limit = @dynamic_table.limit
        updates = []
        updates << @min_limit if @min_limit < @signaled_limit
        updates << limit if limit != updates.last && (!updates.empty? || limit != @signaled_limit)
        @signaled_limit = limit
        @min_limit = nil

        updates.map { |i| Integer.encode(i, 5, 0b00100000) }.join.b
      end
    end
  end
end
