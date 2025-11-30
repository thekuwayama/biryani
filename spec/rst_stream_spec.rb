require_relative 'spec_helper'

RSpec.describe Frame::RstStream do
  context do
    let(:rst_stream1) do
      Frame::RstStream.new(5, 8)
    end
    it 'should encode' do
      expect(rst_stream1.to_binary_s).to eq "\x00\x00\x04\x03\x00\x00\x00\x00\x05\x00\x00\x00\x08".b
    end

    let(:rst_stream2) do
      Frame::RstStream.read("\x00\x00\x04\x03\x00\x00\x00\x00\x05\x00\x00\x00\x08".b)
    end
    it 'should decode' do
      expect(rst_stream2.f_type).to eq FrameType::RST_STREAM
      expect(rst_stream2.stream_id).to eq 5
      expect(rst_stream2.error_code).to eq 8
    end
  end
end
