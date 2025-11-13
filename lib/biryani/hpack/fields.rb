require_relative 'field'

module Biryani
  module HPACK
    module Fields
      def self.encode(fields)
        fields.each_with_object(''.b) { |nv, acc| acc << Field.encode(nv[0].to_s, nv[1].to_s) }
      end
    end
  end
end
