require_relative '../spec_helper'

RSpec.describe Connection do
  context 'close_all_streams' do
    let(:stream_ctxs) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end
    it 'should close' do
      Connection.close_all_streams(stream_ctxs)
      expect { stream_ctxs[1].tx << nil }.to raise_error Ractor::ClosedError
      expect { stream_ctxs[1].err << nil }.to raise_error Ractor::ClosedError
      expect { stream_ctxs[2].tx << nil }.to raise_error Ractor::ClosedError
      expect { stream_ctxs[2].err << nil }.to raise_error Ractor::ClosedError
    end
  end
end
