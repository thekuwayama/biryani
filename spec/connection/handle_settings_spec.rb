require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_settings' do
    let(:send_settings) do
      Connection.default_settings
    end
    let(:decoder) do
      HPACK::Decoder.new(4_096)
    end

    let(:settings1) do
      Frame::Settings.new(false, 0, { SettingsID::SETTINGS_HEADER_TABLE_SIZE => 8_192 })
    end
    it 'should handle' do
      tuple = Connection.handle_settings(settings1, send_settings, decoder)
      expect(tuple[0].ack?).to eq true
      expect(tuple[0].setting.empty?).to eq true
      expect(tuple[1]).to eq 0xffffffff
      expect(tuple[2]).to eq 16_384
      expect(send_settings[SettingsID::SETTINGS_HEADER_TABLE_SIZE]).to eq 8_192
    end

    let(:settings2) do
      Frame::Settings.new(true, 0, {})
    end
    it 'should handle' do
      expect(Connection.handle_settings(settings2, send_settings, decoder)).to eq nil
    end
  end
end
