require_relative 'spec_helper'

RSpec.describe HPACK::Integer do
  context do
    let(:mask) do
      0b00000000
    end

    it 'should encode' do
      expect(HPACK::Integer.encode(10, 5, mask)).to eq "\x0a".b
      expect(HPACK::Integer.encode(1337, 5, mask)).to eq "\x1f\x9a\x0a".b
      expect(HPACK::Integer.encode(42, 8, mask)).to eq "\x2a".b
    end

    let(:cursor) do
      0
    end

    it 'should decode' do
      expect(HPACK::Integer.decode("\x0a".b, 5, cursor)).to eq [10, 1]
      expect(HPACK::Integer.decode("\x1f\x9a\x0a".b, 5, cursor)).to eq [1337, 3]
      expect(HPACK::Integer.decode("\x2a".b, 8, cursor)).to eq [42, 1]
      expect(HPACK::Integer.decode("\x8a".b, 5, cursor)).to eq [10, 1]
    end
  end
end
