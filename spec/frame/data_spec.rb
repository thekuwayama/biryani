require_relative '../spec_helper'

RSpec.describe Frame::Data do
  context do
    let(:data1) do
      Frame::Data.new(false, 2, 'Hello, world!', 'Howdy!')
    end
    it 'should encode' do
      expect(data1.to_binary_s).to eq "\x00\x00\x14\x00\x08\x00\x00\x00\x02\x06\x48\x65\x6c\x6c\x6f\x2c\x20\x77\x6f\x72\x6c\x64\x21\x48\x6f\x77\x64\x79\x21".b
    end

    let(:data2) do
      Frame::Data.read("\x06\x48\x65\x6c\x6c\x6f\x2c\x20\x77\x6f\x72\x6c\x64\x21\x48\x6f\x77\x64\x79\x21".b, 8, 2)
    end
    it 'should decode' do
      expect(data2.f_type).to eq FrameType::DATA
      expect(data2.end_stream?).to eq false
      expect(data2.stream_id).to eq 2
      expect(data2.data).to eq 'Hello, world!'
      expect(data2.padding).to eq 'Howdy!'
      expect(data2.padded?).to eq true
      expect(data2.length).to eq 20
    end
  end
end
