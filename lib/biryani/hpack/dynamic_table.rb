module Biryani
  module HPACK
    class DynamicTable
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
          n, v = @dynamic_table.pop
          @size -= n.bytesize + v.bytesize + 32
        end
      end

      # @param name [String]
      # @param value [String]
      #
      # @return [Some, None]
      def find(name, value)
        nv, i = @table.each_with_index.find { |nv, _| nv[0] == name }
        if nv.nil?
          None.new
        elsif nv[1] == value
          Some.new(i + 1 + STATIC_TABLE.length, nil)
        else
          Some.new(i + 1 + STATIC_TABLE.length, value)
        end
      end

      # @param name [Integer]
      #
      # @return [Array, nil]
      def [](index)
        @table[index]
      end
    end
  end
end
