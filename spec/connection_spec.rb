require_relative 'spec_helper'

RSpec.describe Connection do
  context 'read_http2_magic' do
    let(:io1) do
      StringIO.new("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
    end
    it 'should read' do
      expect { Connection.read_http2_magic(io1) }.not_to raise_error
    end

    let(:io2) do
      StringIO.new("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n\x00xff")
    end
    it 'should read' do
      expect { Connection.read_http2_magic(io2) }.not_to raise_error
    end

    let(:io3) do
      StringIO.new("\x00xffPRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
    end
    it 'should not read' do
      expect { Connection.read_http2_magic(io3) }.to raise_error(RuntimeError)
    end
  end

  context 'handle_window_update' do
    let(:send_window) do
      Window.new
    end
    let(:stream_ctxs) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end

    let(:window_update1) do
      Frame::WindowUpdate.new(1, 1000)
    end
    it 'should handle' do
      expect { Connection.handle_window_update(window_update1, send_window, stream_ctxs) }.not_to raise_error
      expect(send_window.length).to eq 2**16 - 1
      expect(stream_ctxs[1].send_window.length).to eq 2**16 - 1 + 1000
      expect(stream_ctxs[2].send_window.length).to eq 2**16 - 1
    end

    let(:window_update2) do
      Frame::WindowUpdate.new(0, 1000)
    end
    it 'should handle' do
      expect { Connection.handle_window_update(window_update2, send_window, stream_ctxs) }.not_to raise_error
      expect(send_window.length).to eq 2**16 - 1 + 1000
      expect(stream_ctxs[1].send_window.length).to eq 2**16 - 1
      expect(stream_ctxs[2].send_window.length).to eq 2**16 - 1
    end
  end

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
