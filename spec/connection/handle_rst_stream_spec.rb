require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_rst_stream' do
    let(:rst_stream) do
      Frame::RstStream.new(2, 0)
    end
    let(:streams_ctx) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx
    end
    it 'should handle' do
      Connection.handle_rst_stream(rst_stream, streams_ctx)
      expect(streams_ctx.length).to eq 2
      expect(streams_ctx.count_active).to eq 0
      expect(streams_ctx.closed_stream_ids.length).to eq 1
    end
  end
end
