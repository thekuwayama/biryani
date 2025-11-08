require_relative 'spec_helper'

RSpec.describe Biryani::HPACK::Huffman do
  context 'Huffman' do
    it 'should encode' do
      expect(Biryani::HPACK::Huffman.encode('www.example.com')).to eq "\xf1\xe3\xc2\xe5\xf2\x3a\x6b\xa0\xab\x90\xf4\xff".b
      expect(Biryani::HPACK::Huffman.encode('no-cache')).to eq "\xa8\xeb\x10\x64\x9c\xbf".b
    end

    it 'should decode' do
      expect(Biryani::HPACK::Huffman.decode("\xf1\xe3\xc2\xe5\xf2\x3a\x6b\xa0\xab\x90\xf4\xff".b)).to eq 'www.example.com'
      expect(Biryani::HPACK::Huffman.decode("\xa8\xeb\x10\x64\x9c\xbf".b)).to eq 'no-cache'
    end

    it 'should not decode' do
      expect { Biryani::HPACK::Huffman.decode("\xff\xff\xff\xff".b) }.to raise_error(StandardError)
      expect { Biryani::HPACK::Huffman.decode("\xf8\xff".b) }.to raise_error(StandardError)
    end
  end
end
