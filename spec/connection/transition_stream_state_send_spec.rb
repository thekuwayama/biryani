require_relative '../spec_helper'

RSpec.describe Connection do
  context 'transition_stream_state_send' do
    let(:streams_ctx) do
      streams_ctx = StreamsContext.new(do_nothing_proc)
      streams_ctx.new_context(1, 65_535, 65_535)
      streams_ctx.new_context(2, 65_535, 65_535)
      streams_ctx
    end

    let(:headers) do
      Frame::Headers.new(true, true, 2, nil, nil, 'this is dummy', nil)
    end
    it 'should transition' do
      streams_ctx[2].state_transition!(headers, :recv)
      Connection.transition_stream_state_send(headers, streams_ctx)
      expect(streams_ctx.length).to eq 2
    end

    it 'should transition' do
      streams_ctx[1].state_transition!(headers, :recv)
      streams_ctx[2].state_transition!(headers, :recv)
      streams_ctx.close_all
      expect(streams_ctx[1].closed?).to eq true
      expect(streams_ctx[2].closed?).to eq true
    end

    let(:rst_stream) do
      Frame::RstStream.new(2, 0)
    end
    it 'should transition' do
      streams_ctx[2].state_transition!(headers, :recv)
      Connection.transition_stream_state_send(rst_stream, streams_ctx)
      expect(streams_ctx[1].closed?).to eq false
      expect(streams_ctx[2].closed?).to eq true
    end
  end
end
