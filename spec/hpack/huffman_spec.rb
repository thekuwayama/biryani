require_relative '../spec_helper'

RSpec.describe HPACK::Huffman do
  context do
    it 'should encode' do
      expect(HPACK::Huffman.encode('www.example.com')).to eq "\xf1\xe3\xc2\xe5\xf2\x3a\x6b\xa0\xab\x90\xf4\xff".b
      expect(HPACK::Huffman.encode('no-cache')).to eq "\xa8\xeb\x10\x64\x9c\xbf".b
    end

    it 'should decode' do
      expect(HPACK::Huffman.decode(IO::Buffer.for("\xf1\xe3\xc2\xe5\xf2\x3a\x6b\xa0\xab\x90\xf4\xff".b), 0, 12)).to eq 'www.example.com'
      expect(HPACK::Huffman.decode(IO::Buffer.for("\xa8\xeb\x10\x64\x9c\xbf".b), 0, 6)).to eq 'no-cache'
    end

    it 'should not decode' do
      expect { HPACK::Huffman.decode(IO::Buffer.for("\xff\xff\xff\xff".b), 0, 4) }.to raise_error HPACK::Error::HuffmanDecodeError
      expect { HPACK::Huffman.decode(IO::Buffer.for("\xf8\xff".b), 0, 2) }.to raise_error HPACK::Error::HuffmanDecodeError
    end
  end
end
