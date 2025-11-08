require_relative 'spec_helper'

RSpec.describe HPACK::Huffman do
  context 'Huffman' do
    it 'should encode' do
      expect(HPACK::Huffman.encode('www.example.com')).to eq "\xf1\xe3\xc2\xe5\xf2\x3a\x6b\xa0\xab\x90\xf4\xff".b
      expect(HPACK::Huffman.encode('no-cache')).to eq "\xa8\xeb\x10\x64\x9c\xbf".b
    end

    it 'should decode' do
      expect(HPACK::Huffman.decode("\xf1\xe3\xc2\xe5\xf2\x3a\x6b\xa0\xab\x90\xf4\xff".b)).to eq 'www.example.com'
      expect(HPACK::Huffman.decode("\xa8\xeb\x10\x64\x9c\xbf".b)).to eq 'no-cache'
    end

    it 'should not decode' do
      expect { HPACK::Huffman.decode("\xff\xff\xff\xff".b) }.to raise_error(Error::HuffmanDecodeError)
      expect { HPACK::Huffman.decode("\xf8\xff".b) }.to raise_error(Error::HuffmanDecodeError)
    end
  end
end
