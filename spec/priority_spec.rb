require_relative 'spec_helper'

RSpec.describe Frame::Priority do
  context 'Priority' do
    let(:priority) do
      Frame::Priority.new(
        stream_id: 9,
        stream_dependency: 11,
        weight: 8
      )
    end

    it 'should encode' do
      expect(priority.to_binary_s).to eq "\x00\x00\x05\x02\x00\x00\x00\x00\x09\x00\x00\x00\x0b\x08".b
    end

    it 'should decode' do
      expect(Frame::Priority.read("\x00\x00\x05\x02\x00\x00\x00\x00\x09\x00\x00\x00\x0b\x08".b)).to eq priority
    end
  end
end
