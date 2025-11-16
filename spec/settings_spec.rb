require_relative 'spec_helper'

RSpec.describe Frame::Settings do
  context 'Settings' do
    let(:settings) do
      Frame::Settings.new(
        setting: [
          { setting_id: 1, setting_value: 8192 },
          { setting_id: 3, setting_value: 5000 }
        ]
      )
    end

    it 'should encode' do
      expect(settings.to_binary_s).to eq "\x00\x00\x0c\x04\x00\x00\x00\x00\x00\x00\x01\x00\x00\x20\x00\x00\x03\x00\x00\x13\x88".b
    end

    it 'should decode' do
      expect(Frame::Settings.read("\x00\x00\x0c\x04\x00\x00\x00\x00\x00\x00\x01\x00\x00\x20\x00\x00\x03\x00\x00\x13\x88".b)).to eq settings
    end
  end
end
