require_relative '../spec_helper'

RSpec.describe Connection do
  context 'transition_state' do
    let(:stream_ctxs) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end

    let(:data) do
      Frame::Data.new(false, 2, 'Hello, world!', 'Howdy!')
    end
    it 'should transition' do
      Connection.transition_state(data, stream_ctxs)
      expect(stream_ctxs.length).to eq 2
    end

    let(:goaway) do
      Frame::Goaway.new(2, ErrorCode::NO_ERROR, 'debug')
    end
    it 'should transition' do
      Connection.transition_state(goaway, stream_ctxs)
      expect { stream_ctxs[1].tx << nil }.to raise_error Ractor::ClosedError
      expect { stream_ctxs[1].err << nil }.to raise_error Ractor::ClosedError
      expect { stream_ctxs[2].tx << nil }.to raise_error Ractor::ClosedError
      expect { stream_ctxs[2].err << nil }.to raise_error Ractor::ClosedError
    end

    let(:rst_stream) do
      Frame::RstStream.new(2, 0)
    end
    it 'should transition' do
      Connection.transition_state(rst_stream, stream_ctxs)
      expect { stream_ctxs[1].tx << nil }.to_not raise_error
      expect { stream_ctxs[1].err << nil }.to_not raise_error
      expect { stream_ctxs[2].tx << nil }.to raise_error Ractor::ClosedError
      expect { stream_ctxs[2].err << nil }.to raise_error Ractor::ClosedError
    end
  end
end
