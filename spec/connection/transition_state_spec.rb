require_relative '../spec_helper'

RSpec.describe Connection do
  context 'transition_state' do
    let(:streams_ctx) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1)
      streams_ctx.new_context(2)
      streams_ctx
    end

    let(:data) do
      Frame::Data.new(false, 2, 'Hello, world!', 'Howdy!')
    end
    it 'should transition' do
      Connection.transition_state(data, streams_ctx)
      expect(streams_ctx.length).to eq 2
    end

    let(:goaway) do
      Frame::Goaway.new(0, 2, ErrorCode::NO_ERROR, 'debug')
    end
    it 'should transition' do
      Connection.transition_state(goaway, streams_ctx)
      expect { streams_ctx[1].tx << nil }.to raise_error Ractor::ClosedError
      expect { streams_ctx[1].err << nil }.to raise_error Ractor::ClosedError
      expect { streams_ctx[2].tx << nil }.to raise_error Ractor::ClosedError
      expect { streams_ctx[2].err << nil }.to raise_error Ractor::ClosedError
    end

    let(:rst_stream) do
      Frame::RstStream.new(2, 0)
    end
    it 'should transition' do
      Connection.transition_state(rst_stream, streams_ctx)
      expect { streams_ctx[1].tx << nil }.to_not raise_error
      expect { streams_ctx[1].err << nil }.to_not raise_error
      expect { streams_ctx[2].tx << nil }.to raise_error Ractor::ClosedError
      expect { streams_ctx[2].err << nil }.to raise_error Ractor::ClosedError
    end
  end
end
