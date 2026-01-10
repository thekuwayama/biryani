require_relative '../spec_helper'

RSpec.describe Frame::Ping do
  context do
    let(:ping1) do
      Frame::Ping.new(false, 0, 'deadbeef')
    end
    it 'should encode' do
      expect(ping1.to_binary_s).to eq "\x00\x00\x08\x06\x00\x00\x00\x00\x00\x64\x65\x61\x64\x62\x65\x65\x66".b
    end

    let(:ping2) do
      Frame::Ping.read("\x64\x65\x61\x64\x62\x65\x65\x66".b, 0, 0)
    end
    it 'should decode' do
      expect(ping2.f_type).to eq FrameType::PING
      expect(ping2.ack?).to eq false
      expect(ping2.stream_id).to eq 0
      expect(ping2.opaque).to eq 'deadbeef'
    end
  end
end
