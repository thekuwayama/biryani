require_relative '../spec_helper'

RSpec.describe HPACK::String do
  context do
    it 'should encode' do
      expect(HPACK::String.encode('custom-key')).to eq "\x88\x25\xa8\x49\xe9\x5b\xa9\x7d\x7f".b
      expect(HPACK::String.encode('\\')).to eq "\x01\x5c".b
    end

    let(:cursor) do
      0
    end

    it 'should decode' do
      expect(HPACK::String.decode(IO::Buffer.for("\x88\x25\xa8\x49\xe9\x5b\xa9\x7d\x7f".b), cursor)).to eq ['custom-key', 9]
      expect(HPACK::String.decode(IO::Buffer.for("\x01\x5c".b), cursor)).to eq ['\\', 2]
    end

    it 'should not decode' do
      expect { HPACK::String.decode(IO::Buffer.for(''.b), cursor) }.to raise_error HPACK::Error::HPACKDecodeError
      expect { HPACK::String.decode(IO::Buffer.for("\x02\x5c".b), cursor) }.to raise_error HPACK::Error::HPACKDecodeError
      expect { HPACK::String.decode(IO::Buffer.for("\x89\x25\xa8\x49\xe9\x5b\xa9\x7d\x7f".b), cursor) }.to raise_error HPACK::Error::HPACKDecodeError
      expect { HPACK::String.decode(IO::Buffer.for("\x84\xff\xff\xff\xff".b), cursor) }.to raise_error HPACK::Error::HuffmanDecodeError
    end
  end
end
