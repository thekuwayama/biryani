require_relative 'spec_helper'

RSpec.describe HPACK::Integer do
  context 'Integer' do
    it 'should encode' do
      expect(HPACK::Integer.encode(10, 5)).to eq "\x0a".b
      expect(HPACK::Integer.encode(1337, 5)).to eq "\x1f\x9a\x0a".b
      expect(HPACK::Integer.encode(42, 8)).to eq "\x2a".b
    end

    it 'should decode' do
      expect(HPACK::Integer.decode("\x0a".b, 5)).to eq 10
      expect(HPACK::Integer.decode("\x1f\x9a\x0a".b, 5)).to eq 1337
      expect(HPACK::Integer.decode("\x2a".b, 8)).to eq 42
    end
  end
end
