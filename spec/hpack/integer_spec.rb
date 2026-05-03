require_relative '../spec_helper'

RSpec.describe HPACK::Integer do
  context do
    let(:mask) do
      0b00000000
    end

    it 'should encode' do
      expect(HPACK::Integer.encode(10, 5, mask)).to eq "\x0a".b
      expect(HPACK::Integer.encode(1337, 5, mask)).to eq "\x1f\x9a\x0a".b
      expect(HPACK::Integer.encode(42, 8, mask)).to eq "\x2a".b
      expect(HPACK::Integer.encode(31, 5, mask)).to eq "\x1f\x00".b
      expect(HPACK::Integer.encode(255, 7, mask)).to eq "\x7f\x80\x01".b
      expect(HPACK::Integer.encode(3_000_000, 5, mask)).to eq "\x1f\xa1\x8d\xb7\x01".b
    end

    let(:cursor) do
      0
    end

    it 'should decode' do
      expect(HPACK::Integer.decode(IO::Buffer.for("\x0a".b), 5, cursor)).to eq [10, 1]
      expect(HPACK::Integer.decode(IO::Buffer.for("\x1f\x9a\x0a".b), 5, cursor)).to eq [1337, 3]
      expect(HPACK::Integer.decode(IO::Buffer.for("\x2a".b), 8, cursor)).to eq [42, 1]
      expect(HPACK::Integer.decode(IO::Buffer.for("\x8a".b), 5, cursor)).to eq [10, 1]
      expect(HPACK::Integer.decode(IO::Buffer.for("\x0a\x0b".b), 5, 1)).to eq [11, 2]
      expect(HPACK::Integer.decode(IO::Buffer.for("\x1f\x00".b), 5, cursor)).to eq [31, 2]
      expect(HPACK::Integer.decode(IO::Buffer.for("\x7f\x80\x01".b), 7, cursor)).to eq [255, 3]
      expect(HPACK::Integer.decode(IO::Buffer.for("\x1f\xa1\x8d\xb7\x01".b), 5, cursor)).to eq [3_000_000, 5]
    end
  end
end
