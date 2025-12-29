require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_stream_window_update' do
    let(:window_update) do
      Frame::WindowUpdate.new(1, 1000)
    end
    let(:streams_ctx) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, do_nothing_proc)
      streams_ctx.new_context(2, do_nothing_proc)
      streams_ctx
    end
    it 'should handle' do
      expect { Connection.handle_stream_window_update(window_update, streams_ctx) }.not_to raise_error
      expect(streams_ctx[1].send_window.length).to eq 2**16 - 1 + 1000
      expect(streams_ctx[2].send_window.length).to eq 2**16 - 1
    end
  end
end
