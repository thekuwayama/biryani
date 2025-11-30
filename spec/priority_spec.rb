require_relative 'spec_helper'

RSpec.describe Frame::Priority do
  context do
    let(:priority1) do
      Frame::Priority.new(9, 11, 8)
    end
    it 'should encode' do
      expect(priority1.to_binary_s).to eq "\x00\x00\x05\x02\x00\x00\x00\x00\x09\x00\x00\x00\x0b\x08".b
    end

    let(:priority2) do
      Frame::Priority.read("\x00\x00\x05\x02\x00\x00\x00\x00\x09\x00\x00\x00\x0b\x08".b)
    end
    it 'should decode' do
      expect(priority2.f_type).to eq FrameType::PRIORITY
      expect(priority2.stream_id).to eq 9
      expect(priority2.stream_dependency).to eq 11
      expect(priority2.weight).to eq 8
    end
  end
end
