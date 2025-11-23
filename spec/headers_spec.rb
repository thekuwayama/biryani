require_relative 'spec_helper'

RSpec.describe Frame::Headers do
  context 'Headers' do
    let(:headers1) do
      Frame::Headers.new(true, false, 1, nil, nil, 'this is dummy', nil)
    end
    it 'should encode' do
      expect(headers1.to_binary_s).to eq "\x00\x00\x0d\x01\x04\x00\x00\x00\x01\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79".b
    end

    let(:headers2) do
      Frame::Headers.new(true, false, 3, 20, 10, 'this is dummy', 'This is padding.')
    end
    it 'should encode' do
      expect(headers2.to_binary_s)
        .to eq "\x00\x00\x23\x01\x2c\x00\x00\x00\x03\x10\x80\x00\x00\x14\x0a\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79\x54\x68\x69\x73\x20\x69\x73\x20\x70\x61\x64\x64\x69\x6e\x67\x2e".b
    end

    let(:headers3) do
      Frame::Headers.read("\x00\x00\x0d\x01\x04\x00\x00\x00\x01\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79".b)
    end
    it 'should decode' do
      expect(headers3.f_type).to eq FrameType::HEADERS
      expect(headers3.end_headers).to be true
      expect(headers3.end_stream).to be false
      expect(headers3.stream_id).to be 1
      expect(headers3.stream_dependency).to be nil
      expect(headers3.weight).to be nil
      expect(headers3.fragment).to eq 'this is dummy'
      expect(headers3.padding).to eq nil
      expect(headers3.priority?).to eq false
      expect(headers3.padded?).to eq false
      expect(headers3.exclusive?).to eq false
    end

    let(:headers4) do
      Frame::Headers.read("\x00\x00\x23\x01\x2c\x00\x00\x00\x03\x10\x80\x00\x00\x14\x0a\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79\x54\x68\x69\x73\x20\x69\x73\x20\x70\x61\x64\x64\x69\x6e\x67\x2e".b)
    end
    it 'should decode' do
      expect(headers4.f_type).to eq FrameType::HEADERS
      expect(headers4.end_headers).to be true
      expect(headers4.end_stream).to be false
      expect(headers4.stream_id).to be 3
      expect(headers4.stream_dependency).to be 20
      expect(headers4.weight).to be 10
      expect(headers4.fragment).to eq 'this is dummy'
      expect(headers4.padding).to eq 'This is padding.'
      expect(headers4.priority?).to eq true
      expect(headers4.padded?).to eq true
      expect(headers4.exclusive?).to eq true
    end
  end
end
