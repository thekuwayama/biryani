module Biryani
  module HPACK
    class Encoder
      # @param max_size_limit [Integer]
      def initialize(max_size_limit)
        @dynamic_table = DynamicTable.new(max_size_limit)
        @signaled_max_size = max_size_limit
        @min_max_size = nil
      end

      # @param fields [Array]
      #
      # @return [String]
      def encode(fields)
        (dynamic_table_size_update + Fields.encode(fields, @dynamic_table)).force_encoding(Encoding::ASCII_8BIT)
      end

      # @param new_max_size_limit [Integer]
      def max_size_limit!(new_max_size_limit)
        @dynamic_table.max_size_limit!(new_max_size_limit)
        @min_max_size = [@min_max_size || new_max_size_limit, new_max_size_limit].min
      end

      private

      # https://datatracker.ietf.org/doc/html/rfc7541#section-4.2
      #
      # @return [String]
      def dynamic_table_size_update
        return ''.b if @min_max_size.nil?

        max_size = @dynamic_table.max_size
        updates = []
        updates << @min_max_size if @min_max_size < @signaled_max_size
        updates << max_size if max_size != updates.last && (!updates.empty? || max_size != @signaled_max_size)
        @signaled_max_size = max_size
        @min_max_size = nil

        updates.map { |i| Integer.encode(i, 5, 0b00100000) }.join.b
      end
    end
  end
end
