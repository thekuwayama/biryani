require_relative 'spec_helper'

RSpec.describe Frame::WindowUpdate do
  context 'WindowUpdate' do
    let(:window_update) do
      Frame::WindowUpdate.new(
        stream_id: 50,
        window_size_increment: 1000
      )
    end

    it 'should encode' do
      expect(window_update.to_binary_s).to eq "\x00\x00\x04\x08\x00\x00\x00\x00\x32\x00\x00\x03\xe8".b
    end

    it 'should decode' do
      expect(Frame::WindowUpdate.read("\x00\x00\x04\x08\x00\x00\x00\x00\x32\x00\x00\x03\xe8".b)).to eq window_update
    end
  end
end
