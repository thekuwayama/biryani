require_relative '../spec_helper'

RSpec.describe Connection do
  context 'close_all_streams' do
    let(:streams_ctx) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx
    end
    it 'should close' do
      Connection.close_all_streams(streams_ctx)
      expect { streams_ctx[1].tx << nil }.to raise_error Ractor::ClosedError
      expect { streams_ctx[2].tx << nil }.to raise_error Ractor::ClosedError
    end
  end
end
