require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_stream_window_update' do
    let(:window_update) do
      Frame::WindowUpdate.new(1, 1000)
    end
    let(:stream_ctxs) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end
    it 'should handle' do
      expect { Connection.handle_stream_window_update(window_update, stream_ctxs) }.not_to raise_error
      expect(stream_ctxs[1].send_window.length).to eq 2**16 - 1 + 1000
      expect(stream_ctxs[2].send_window.length).to eq 2**16 - 1
    end
  end
end
