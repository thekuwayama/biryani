require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_settings' do
    let(:send_settings) do
      Connection.default_settings
    end

    let(:settings1) do
      Frame::Settings.new(false, [[SettingsID::SETTINGS_HEADER_TABLE_SIZE, 8192]])
    end
    it 'should handle' do
      expect(Connection.handle_settings(settings1, send_settings)).to_not eq nil
      expect(Connection.handle_settings(settings1, send_settings).ack?).to eq true
      expect(Connection.handle_settings(settings1, send_settings).setting).to eq []
      expect(send_settings[SettingsID::SETTINGS_HEADER_TABLE_SIZE]).to eq 8192
    end

    let(:settings2) do
      Frame::Settings.new(true, [])
    end
    it 'should handle' do
      expect(Connection.handle_settings(settings2, send_settings)).to eq nil
    end
  end
end
