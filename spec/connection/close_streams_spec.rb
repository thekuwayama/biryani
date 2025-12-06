require_relative '../spec_helper'

RSpec.describe Connection do
  context 'close_streams' do
    let(:stream_ctxs1) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end
    let(:data_buffer1) do
      DataBuffer.new
    end
    it 'should close' do
      Connection.close_streams(stream_ctxs1, data_buffer1)
      expect(stream_ctxs1.length).to eq 2
    end

    let(:stream_ctxs2) do
      stream_ctxs = { 1 => StreamContext.new, 2 => StreamContext.new }
      stream_ctxs[2].state = :closed
      stream_ctxs
    end
    let(:data_buffer2) do
      DataBuffer.new
    end
    it 'should close' do
      Connection.close_streams(stream_ctxs2, data_buffer2)
      expect(stream_ctxs2.length).to eq 1
    end

    let(:stream_ctxs3) do
      stream_ctxs = { 1 => StreamContext.new, 2 => StreamContext.new }
      stream_ctxs[2].state = :closed
      stream_ctxs
    end
    let(:data_buffer3) do
      data_buffer = DataBuffer.new
      data_buffer << Frame::Data.new(false, 2, 'two', nil)
      data_buffer
    end
    it 'should close' do
      Connection.close_streams(stream_ctxs3, data_buffer3)
      expect(stream_ctxs3.length).to eq 2
    end
  end
end
