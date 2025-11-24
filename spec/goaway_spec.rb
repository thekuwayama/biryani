require_relative 'spec_helper'

RSpec.describe Frame::Goaway do
  context 'Goaway' do
    let(:goaway1) do
      Frame::Goaway.new(30, 9, 'hpack is broken')
    end
    it 'should encode' do
      expect(goaway1.to_binary_s).to eq "\x00\x00\x17\x07\x00\x00\x00\x00\x00\x00\x00\x00\x1e\x00\x00\x00\x09\x68\x70\x61\x63\x6b\x20\x69\x73\x20\x62\x72\x6f\x6b\x65\x6e".b
    end

    let(:goaway2) do
      Frame::Goaway.read("\x00\x00\x17\x07\x00\x00\x00\x00\x00\x00\x00\x00\x1e\x00\x00\x00\x09\x68\x70\x61\x63\x6b\x20\x69\x73\x20\x62\x72\x6f\x6b\x65\x6e".b)
    end
    it 'should decode' do
      expect(goaway2.f_type).to eq FrameType::GOAWAY
      expect(goaway2.stream_id).to eq 0
      expect(goaway2.last_stream_id).to eq 30
      expect(goaway2.error_code).to eq 9
      expect(goaway2.debug).to eq 'hpack is broken'
    end
  end
end
