module Biryani
  module HPACK
    class Encoder
      # @param max_size_limit [Integer]
      def initialize(max_size_limit)
        @dynamic_table = DynamicTable.new(max_size_limit)
        @unsignaled_min_max_size = nil
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
        @unsignaled_min_max_size = [@unsignaled_min_max_size || new_max_size_limit, new_max_size_limit].min
      end

      private

      # signal @unsignaled_min_max_size, the smallest max_size not yet signaled since the last field block,
      # before the final max_size so that the decoder evicts the same entries.
      # https://datatracker.ietf.org/doc/html/rfc7541#section-4.2
      # https://datatracker.ietf.org/doc/html/rfc7541#section-6.3
      #
      # @return [String]
      def dynamic_table_size_update
        return ''.b if @unsignaled_min_max_size.nil?

        updates = [@unsignaled_min_max_size, @dynamic_table.max_size].uniq
        @unsignaled_min_max_size = nil

        updates.map { |i| Integer.encode(i, 5, 0b00100000) }.join.b
      end
    end
  end
end
