require_relative 'spec_helper'

RSpec.describe Frame::Headers do
  context 'Headers' do
    let(:headers1) do
      Frame::Headers.new(
        end_headers: true,
        stream_id: 1,
        fragment: 'this is dummy'
      )
    end

    let(:headers2) do
      Frame::Headers.new(
        priority: true,
        padded: true,
        end_headers: true,
        stream_id: 3,
        exclusive: true,
        stream_dependency: 20,
        weight: 10,
        fragment: 'this is dummy',
        padding: 'This is padding.'
      )
    end

    it 'should encode' do
      expect(headers1.to_binary_s).to eq "\x00\x00\x0d\x01\x04\x00\x00\x00\x01\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79".b
      expect(headers2.to_binary_s)
        .to eq "\x00\x00\x23\x01\x2c\x00\x00\x00\x03\x10\x80\x00\x00\x14\x0a\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79\x54\x68\x69\x73\x20\x69\x73\x20\x70\x61\x64\x64\x69\x6e\x67\x2e".b
    end

    it 'should decode' do
      expect(Frame::Headers.read("\x00\x00\x0d\x01\x04\x00\x00\x00\x01\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79".b)).to eq headers1
      expect(Frame::Headers.read(
               "\x00\x00\x23\x01\x2c\x00\x00\x00\x03\x10\x80\x00\x00\x14\x0a\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79\x54\x68\x69\x73\x20\x69\x73\x20\x70\x61\x64\x64\x69\x6e\x67\x2e".b
             )).to eq headers2
    end
  end
end
