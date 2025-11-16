require_relative 'spec_helper'

RSpec.describe Frame::Goaway do
  context 'Goaway' do
    let(:goaway) do
      Frame::Goaway.new(
        last_stream_id: 30,
        error_code: 9,
        debug: 'hpack is broken'
      )
    end

    it 'should encode' do
      expect(goaway.to_binary_s).to eq "\x00\x00\x17\x07\x00\x00\x00\x00\x00\x00\x00\x00\x1e\x00\x00\x00\x09\x68\x70\x61\x63\x6b\x20\x69\x73\x20\x62\x72\x6f\x6b\x65\x6e".b
    end

    it 'should decode' do
      expect(Frame::Goaway.read("\x00\x00\x17\x07\x00\x00\x00\x00\x00\x00\x00\x00\x1e\x00\x00\x00\x09\x68\x70\x61\x63\x6b\x20\x69\x73\x20\x62\x72\x6f\x6b\x65\x6e".b)).to eq goaway
    end
  end
end
