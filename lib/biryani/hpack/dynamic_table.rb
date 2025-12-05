module Biryani
  module HPACK
    class DynamicTable
      # @param limit [Integer]
      def initialize(limit)
        @table = []
        @size = 0
        @limit = limit
      end

      # @param name [String]
      # @param value [String]
      def store(name, value)
        @table.unshift([name, value])
        @size += name.bytesize + value.bytesize + 32
        while @size > @limit
          n, v = @table.pop
          @size -= n.bytesize + v.bytesize + 32
        end
      end

      # @param name [String]
      # @param value [String]
      #
      # @return [Array]
      # @return [Integer]
      def find_field(name, value)
        @table.each_with_index.find { |nv, _| nv[0] == name && nv[1] == value }
      end

      # @param name [String]
      #
      # @return [Array]
      # @return [Integer]
      def find_name(name)
        @table.each_with_index.find { |nv, _| nv[0] == name }
      end

      # @param name [Integer]
      #
      # @return [Array, nil]
      def [](index)
        @table[index]
      end

      # @param new_limit [Integer]
      def limit!(new_limit)
        while @size > new_limit
          n, v = @table.pop
          @size -= n.bytesize + v.bytesize + 32
        end

        @limit = new_limit
      end
    end
  end
end
