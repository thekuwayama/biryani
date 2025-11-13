require_relative 'field'

module Biryani
  module HPACK
    module Fields
      def self.encode(fields)
        fields.map do |n, v|
          Field.encode(n.to_s, v.to_s)
        end
      end
    end
  end
end
