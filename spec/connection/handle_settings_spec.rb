require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_settings' do
    let(:send_settings) do
      Connection.default_settings
    end
    let(:decoder) do
      HPACK::Decoder.new(4_096)
    end
    let(:streams_ctx) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx
    end

    let(:settings1) do
      Frame::Settings.new(false, 0, { SettingsID::SETTINGS_HEADER_TABLE_SIZE => 8_192 })
    end
    it 'should handle' do
      reply_settings = Connection.handle_settings(settings1, send_settings, decoder, streams_ctx)
      expect(reply_settings.ack?).to eq true
      expect(reply_settings.setting.empty?).to eq true
      expect(send_settings[SettingsID::SETTINGS_MAX_CONCURRENT_STREAMS]).to eq 0xffffffff
      expect(send_settings[SettingsID::SETTINGS_MAX_FRAME_SIZE]).to eq 16_384
      expect(send_settings[SettingsID::SETTINGS_HEADER_TABLE_SIZE]).to eq 8_192
    end

    let(:settings2) do
      Frame::Settings.new(true, 0, {})
    end
    it 'should handle' do
      expect(Connection.handle_settings(settings2, send_settings, decoder, streams_ctx)).to eq nil
    end
  end
end
