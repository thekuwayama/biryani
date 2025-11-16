require_relative 'spec_helper'

RSpec.describe Frame::Data do
  context 'Data' do
    let(:data) do
      Frame::Data.new(
        padded: true,
        stream_id: 2,
        data: 'Hello, world!',
        padding: 'Howdy!'
      )
    end

    it 'should encode' do
      expect(data.to_binary_s).to eq "\x00\x00\x14\x00\x08\x00\x00\x00\x02\x06\x48\x65\x6c\x6c\x6f\x2c\x20\x77\x6f\x72\x6c\x64\x21\x48\x6f\x77\x64\x79\x21".b
    end

    it 'should decode' do
      expect(Frame::Data.read("\x00\x00\x14\x00\x08\x00\x00\x00\x02\x06\x48\x65\x6c\x6c\x6f\x2c\x20\x77\x6f\x72\x6c\x64\x21\x48\x6f\x77\x64\x79\x21".b)).to eq data
    end
  end
end
