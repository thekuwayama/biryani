require_relative '../spec_helper'

RSpec.describe Connection do
  context 'transition_state' do
    let(:streams_ctx) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1)
      streams_ctx.new_context(2)
      streams_ctx
    end

    let(:headers) do
      Frame::Headers.new(true, true, 2, nil, nil, 'this is dummy', nil)
    end
    it 'should transition' do
      streams_ctx[2].state.transition!(headers, :recv)
      Connection.transition_state(headers, streams_ctx)
      expect(streams_ctx.length).to eq 2
    end

    it 'should transition' do
      streams_ctx[1].state.transition!(headers, :recv)
      streams_ctx[2].state.transition!(headers, :recv)
      Connection.close_all_streams(streams_ctx)
      expect { streams_ctx[1].tx << nil }.to raise_error Ractor::ClosedError
      expect { streams_ctx[1].err << nil }.to raise_error Ractor::ClosedError
      expect { streams_ctx[2].tx << nil }.to raise_error Ractor::ClosedError
      expect { streams_ctx[2].err << nil }.to raise_error Ractor::ClosedError
    end

    let(:rst_stream) do
      Frame::RstStream.new(2, 0)
    end
    it 'should transition' do
      streams_ctx[2].state.transition!(headers, :recv)
      Connection.transition_state(rst_stream, streams_ctx)
      expect { streams_ctx[1].tx << nil }.to_not raise_error
      expect { streams_ctx[1].err << nil }.to_not raise_error
      expect { streams_ctx[2].tx << nil }.to_not raise_error
      expect { streams_ctx[2].err << nil }.to_not raise_error
    end
  end
end
