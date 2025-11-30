require_relative '../spec_helper'

RSpec.describe Connection do
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
end
