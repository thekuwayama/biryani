require_relative '../spec_helper'

RSpec.describe Connection do
  context 'delete_streams' do
    let(:streams_ctx1) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, do_nothing_proc)
      streams_ctx.new_context(2, do_nothing_proc)
      streams_ctx
    end
    let(:data_buffer1) do
      DataBuffer.new
    end
    it 'should close' do
      Connection.delete_streams(streams_ctx1, data_buffer1)
      expect(streams_ctx1.length).to eq 2
    end

    let(:streams_ctx2) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, do_nothing_proc)
      streams_ctx.new_context(2, do_nothing_proc)
      streams_ctx[2].state.close
      streams_ctx
    end
    let(:data_buffer2) do
      DataBuffer.new
    end
    it 'should close' do
      Connection.delete_streams(streams_ctx2, data_buffer2)
      expect(streams_ctx2.length).to eq 1
    end

    let(:streams_ctx3) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, do_nothing_proc)
      streams_ctx.new_context(2, do_nothing_proc)
      streams_ctx[2].state.close
      streams_ctx
    end
    let(:data_buffer3) do
      data_buffer = DataBuffer.new
      data_buffer << Frame::Data.new(false, 2, 'two', nil)
      data_buffer
    end
    it 'should close' do
      Connection.delete_streams(streams_ctx3, data_buffer3)
      expect(streams_ctx3.length).to eq 2
    end
  end
end
