require_relative 'spec_helper'

RSpec.describe StreamsContext do
  context 'close_all' do
    let(:streams_ctx) do
      streams_ctx = StreamsContext.new(do_nothing_proc, Ractor::Port.new)
      streams_ctx.new_context(1, 65_535, 65_535)
      streams_ctx.new_context(2, 65_535, 65_535)
      streams_ctx
    end
    it 'should close' do
      streams_ctx.close_all
      expect(streams_ctx[1].closed?).to eq true
      expect(streams_ctx[2].closed?).to eq true
    end
  end

  context 'remove_closed' do
    let(:streams_ctx1) do
      streams_ctx = StreamsContext.new(do_nothing_proc, Ractor::Port.new)
      streams_ctx.new_context(1, 65_535, 65_535)
      streams_ctx.new_context(2, 65_535, 65_535)
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
      streams_ctx = StreamsContext.new(do_nothing_proc, Ractor::Port.new)
      streams_ctx.new_context(1, 65_535, 65_535)
      streams_ctx.new_context(2, 65_535, 65_535)
      streams_ctx[2].close
      streams_ctx
    end
    let(:data_buffer2) do
      DataBuffer.new
    end
    it 'should remove' do
      streams_ctx2.remove_closed(data_buffer2)
      expect(streams_ctx2.length).to eq 1
    end

    let(:streams_ctx3) do
      streams_ctx = StreamsContext.new(do_nothing_proc, Ractor::Port.new)
      streams_ctx.new_context(1, 65_535, 65_535)
      streams_ctx.new_context(2, 65_535, 65_535)
      streams_ctx[2].close
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

  context 'none_half_closed_remote?' do
    let(:headers) do
      Frame::Headers.new(true, true, 1, nil, nil, 'this is dummy', nil)
    end
    let(:streams_ctx1) do
      streams_ctx = StreamsContext.new(do_nothing_proc, Ractor::Port.new)
      streams_ctx.new_context(1, 65_535, 65_535)
      streams_ctx
    end
    it 'should not have half_closed_remote' do
      expect(streams_ctx1.none_half_closed_remote?).to eq true
    end

    let(:streams_ctx2) do
      streams_ctx = StreamsContext.new(do_nothing_proc, Ractor::Port.new)
      streams_ctx.new_context(1, 65_535, 65_535)
      streams_ctx[1].state_transition!(headers, :recv)
      streams_ctx
    end
    it 'should have half_closed_remote' do
      expect(streams_ctx2.none_half_closed_remote?).to eq false
    end

    let(:streams_ctx3) do
      streams_ctx = StreamsContext.new(do_nothing_proc, Ractor::Port.new)
      streams_ctx.new_context(1, 65_535, 65_535)
      streams_ctx[1].state_transition!(headers, :recv)
      streams_ctx[1].state_transition!(headers, :send)
      streams_ctx
    end
    it 'should not have half_closed_remote' do
      expect(streams_ctx3.none_half_closed_remote?).to eq true
    end

    let(:streams_ctx4) do
      streams_ctx = StreamsContext.new(do_nothing_proc, Ractor::Port.new)
      streams_ctx.new_context(1, 65_535, 65_535)
      streams_ctx[1].state_transition!(Frame::Headers.new(true, false, 1, nil, nil, 'this is dummy', nil), :recv)
      streams_ctx
    end
    it 'should not have half_closed_remote' do
      expect(streams_ctx4.none_half_closed_remote?).to eq true
    end
  end
end
