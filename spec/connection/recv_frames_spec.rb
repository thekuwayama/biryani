require_relative '../spec_helper'

RSpec.describe Connection do
  context 'recv_frames' do
    let(:ping) do
      Frame::Ping.new(false, 0, "ping\x00\x00\x00\x00")
    end

    let(:port1) do
      Ractor::Port.new
    end
    it 'should send frames and eof' do
      Connection.recv_frames(StringIO.new(ping.to_binary_s), port1)
      typ, frame = port1.receive
      expect(typ).to eq :frame
      expect(frame).to be_kind_of Frame::Ping
      expect(frame.opaque).to eq "ping\x00\x00\x00\x00"
      expect(port1.receive).to eq :eof
    end

    let(:port2) do
      port = Ractor::Port.new
      port.close
      port
    end
    it 'should not linger after EOF' do
      expect(Connection).not_to receive(:linger)
      Connection.recv_frames(StringIO.new, port2)
    end

    it 'should linger before EOF' do
      expect(Connection).to receive(:linger)
      Connection.recv_frames(StringIO.new(ping.to_binary_s), port2)
    end
  end
end
