module Biryani
  module HPACK
    class Some
      attr_reader :index, :value

      def initialize(index, value)
        @index = index
        @value = value
      end

      def deconstruct
        [@index, @value]
      end
    end

    class None
      def initialize; end

      def deconstruct
        []
      end
    end
  end
end
