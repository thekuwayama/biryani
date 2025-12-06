require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_rst_stream' do
    let(:rst_stream) do
      Frame::RstStream.new(2, 0)
    end
    let(:stream_ctxs) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end
    it 'should handle' do
      Connection.handle_rst_stream(rst_stream, stream_ctxs)
      expect(stream_ctxs.length).to eq 2
      expect(stream_ctxs.values.filter(&:active?).length).to eq 0
      expect(stream_ctxs.values.filter(&:closed?).length).to eq 1
    end
  end
end
