require_relative '../spec_helper'

RSpec.describe Frame::WindowUpdate do
  context do
    let(:window_update1) do
      Frame::WindowUpdate.new(50, 1000)
    end
    it 'should encode' do
      expect(window_update1.to_binary_s).to eq "\x00\x00\x04\x08\x00\x00\x00\x00\x32\x00\x00\x03\xe8".b
    end

    let(:window_update2) do
      Frame::WindowUpdate.read("\x00\x00\x04\x08\x00\x00\x00\x00\x32\x00\x00\x03\xe8".b)
    end
    it 'should decode' do
      expect(window_update2.f_type).to eq FrameType::WINDOW_UPDATE
      expect(window_update2.stream_id).to eq 50
      expect(window_update2.window_size_increment).to eq 1000
    end
  end
end
