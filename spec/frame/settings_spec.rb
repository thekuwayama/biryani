require_relative '../spec_helper'

RSpec.describe Frame::Settings do
  context do
    let(:settings1) do
      Frame::Settings.new(false, 0, { 1 => 8192, 3 => 5000 })
    end
    it 'should encode' do
      expect(settings1.to_binary_s).to eq "\x00\x00\x0c\x04\x00\x00\x00\x00\x00\x00\x01\x00\x00\x20\x00\x00\x03\x00\x00\x13\x88".b
    end

    let(:settings2) do
      Frame::Settings.read("\x00\x00\x0c\x04\x00\x00\x00\x00\x00\x00\x01\x00\x00\x20\x00\x00\x03\x00\x00\x13\x88".b)
    end
    it 'should decode' do
      expect(settings2.f_type).to eq FrameType::SETTINGS
      expect(settings2.ack?).to eq false
      expect(settings2.stream_id).to eq 0
      expect(settings2.setting[1]).to eq 8192
      expect(settings2.setting[3]).to eq 5000
    end
  end
end
