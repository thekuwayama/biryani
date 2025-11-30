require_relative 'spec_helper'

RSpec.describe DataBuffer do
  context 'take!' do
    let(:data_buffer1) do
      DataBuffer.new
    end
    let(:send_window1) do
      Window.new
    end
    let(:stream_ctxs1) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end
    it 'should take' do
      expect(data_buffer1.take!(send_window1, stream_ctxs1).length).to eq 0
      expect(send_window1.length).to eq 2**16 - 1
      expect(stream_ctxs1.values.map(&:send_window).map(&:length)).to eq [2**16 - 1, 2**16 - 1]
    end

    let(:data_buffer2) do
      data_buffer = DataBuffer.new
      data_buffer << Frame::Data.new(false, 1, 'one', nil)
      data_buffer << Frame::Data.new(false, 2, 'two', nil)
      data_buffer
    end
    let(:send_window2) do
      Window.new
    end
    let(:stream_ctxs2) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end
    it 'should take' do
      datas = data_buffer2.take!(send_window2, stream_ctxs2)
      expect(datas.length).to eq 2
      expect(datas.map(&:stream_id)).to eq [1, 2]
      expect(datas.map(&:data)).to eq %w[one two]
      expect(send_window2.length).to eq 2**16 - 7
      expect(stream_ctxs2.values.map(&:send_window).map(&:length)).to eq [2**16 - 4, 2**16 - 4]
    end

    let(:data_buffer3) do
      data_buffer = DataBuffer.new
      data_buffer << Frame::Data.new(false, 2, 'two', nil)
      data_buffer
    end
    let(:send_window3) do
      Window.new
    end
    let(:stream_ctxs3) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end
    it 'should take' do
      datas = data_buffer3.take!(send_window3, stream_ctxs3)
      expect(datas.length).to eq 1
      expect(datas.first.stream_id).to eq 2
      expect(datas.first.data).to eq 'two'
      expect(send_window3.length).to eq 2**16 - 4
      expect(stream_ctxs3.values.map(&:send_window).map(&:length)).to eq [2**16 - 1, 2**16 - 4]
    end

    let(:data_buffer4) do
      data_buffer = DataBuffer.new
      data_buffer << Frame::Data.new(false, 1, 'one', nil)
      data_buffer << Frame::Data.new(false, 2, 'two', nil)
      data_buffer
    end
    let(:send_window4) do
      Window.new
    end
    let(:stream_ctxs4) do
      stream_ctxs = { 1 => StreamContext.new, 2 => StreamContext.new }
      stream_ctxs[1].send_window.consume!(2**16 - 1)
      stream_ctxs
    end
    it 'should take' do
      datas = data_buffer4.take!(send_window4, stream_ctxs4)
      expect(datas.length).to eq 1
      expect(datas.first.stream_id).to eq 2
      expect(datas.first.data).to eq 'two'
      expect(send_window4.length).to eq 2**16 - 4
      expect(stream_ctxs4.values.map(&:send_window).map(&:length)).to eq [0, 2**16 - 4]
    end

    let(:data_buffer5) do
      data_buffer = DataBuffer.new
      data_buffer << Frame::Data.new(false, 1, 'one', nil)
      data_buffer << Frame::Data.new(false, 2, 'two', nil)
      data_buffer
    end
    let(:send_window5) do
      send_window = Window.new
      send_window.consume!(2**16 - 1)
      send_window
    end
    let(:stream_ctxs5) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end
    it 'should take' do
      expect(data_buffer5.take!(send_window5, stream_ctxs5).length).to eq 0
      expect(send_window5.length).to eq 0
      expect(stream_ctxs5.values.map(&:send_window).map(&:length)).to eq [2**16 - 1, 2**16 - 1]
    end
  end
end
