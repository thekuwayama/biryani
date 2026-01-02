require_relative 'spec_helper'

RSpec.describe StreamsContext do
  context 'close_all' do
    let(:streams_ctx) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx
    end
    it 'should close' do
      streams_ctx.close_all
      expect { streams_ctx[1].tx << nil }.to raise_error Ractor::ClosedError
      expect { streams_ctx[2].tx << nil }.to raise_error Ractor::ClosedError
    end
  end

  context 'close_all' do
    let(:streams_ctx) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx
    end
    it 'should close' do
      streams_ctx.close_all
      expect { streams_ctx[1].tx << nil }.to raise_error Ractor::ClosedError
      expect { streams_ctx[2].tx << nil }.to raise_error Ractor::ClosedError
    end
  end

  context 'remove_closed' do
    let(:streams_ctx1) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx
    end
    let(:data_buffer1) do
      DataBuffer.new
    end
    it 'should remove' do
      streams_ctx1.remove_closed(data_buffer1)
      expect(streams_ctx1.length).to eq 2
    end

    let(:streams_ctx2) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx[2].state.close
      streams_ctx
    end
    let(:data_buffer2) do
      DataBuffer.new
    end
    it 'should remove' do
      streams_ctx2.remove_closed(data_buffer2)
      expect(streams_ctx2.length).to eq 2 # remain stream_id
    end

    let(:streams_ctx3) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx[2].state.close
      streams_ctx
    end
    let(:data_buffer3) do
      data_buffer = DataBuffer.new
      data_buffer.store(2, 'two')
      data_buffer
    end
    it 'should remove' do
      streams_ctx3.remove_closed(data_buffer3)
      expect(streams_ctx3.length).to eq 2
    end
  end
end
