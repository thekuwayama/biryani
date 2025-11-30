require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_ping' do
    let(:ping1) do
      Frame::Ping.new(true, "\x00" * 8)
    end
    it 'should handle' do
      expect(Connection.handle_ping(ping1)).to eq nil
    end

    let(:ping2) do
      Frame::Ping.new(false, "\x00" * 8)
    end
    it 'should handle' do
      expect(Connection.handle_ping(ping2)).to_not eq nil
      expect(Connection.handle_ping(ping2).ack?).to eq true
      expect(Connection.handle_ping(ping2).opaque).to eq "\x00" * 8
    end
  end
end
