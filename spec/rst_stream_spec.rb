require_relative 'spec_helper'

RSpec.describe Frame::RstStream do
  context 'RstStream' do
    let(:rst_stream) do
      Frame::RstStream.new(
        stream_id: 5,
        error_code: 8
      )
    end

    it 'should encode' do
      expect(rst_stream.to_binary_s).to eq "\x00\x00\x04\x03\x00\x00\x00\x00\x05\x00\x00\x00\x08".b
    end

    it 'should decode' do
      expect(Frame::RstStream.read("\x00\x00\x04\x03\x00\x00\x00\x00\x05\x00\x00\x00\x08".b)).to eq rst_stream
    end
  end
end
