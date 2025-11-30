require_relative '../spec_helper'

RSpec.describe Connection do
  context 'send' do
    let(:io) do
      StringIO.new
    end
    let(:data_buffer) do
      DataBuffer.new
    end

    let(:frame1) do
      Frame::Data.new(false, 2, 'Hello, world!', 'Howdy!')
    end
    let(:send_window1) do
      Window.new
    end
    let(:stream_ctxs1) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end
    it 'should send' do
      Connection.send(io, frame1, send_window1, stream_ctxs1, data_buffer)
      expect(io.string).to eq "\x00\x00\x14\x00\x08\x00\x00\x00\x02\x06\x48\x65\x6c\x6c\x6f\x2c\x20\x77\x6f\x72\x6c\x64\x21\x48\x6f\x77\x64\x79\x21".b
      expect(send_window1.length).to eq 2**16 - 21
      expect(stream_ctxs1.values.map(&:send_window).map(&:length)).to eq [2**16 - 1, 2**16 - 21]
      expect(data_buffer.length).to eq 0
    end

    let(:frame2) do
      Frame::Headers.new(true, false, 1, nil, nil, 'this is dummy', nil)
    end
    let(:send_window2) do
      Window.new
    end
    let(:stream_ctxs2) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end
    it 'should send' do
      Connection.send(io, frame2, send_window2, stream_ctxs2, data_buffer)
      expect(io.string).to eq "\x00\x00\x0d\x01\x04\x00\x00\x00\x01\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79".b
      expect(send_window2.length).to eq 2**16 - 1
      expect(stream_ctxs2.values.map(&:send_window).map(&:length)).to eq [2**16 - 1, 2**16 - 1]
      expect(data_buffer.length).to eq 0
    end

    let(:frame3) do
      Frame::Data.new(false, 2, 'Hello, world!', 'Howdy!')
    end
    let(:send_window3) do
      Window.new
    end
    let(:stream_ctxs3) do
      stream_ctxs = { 1 => StreamContext.new, 2 => StreamContext.new }
      stream_ctxs[2].send_window.consume!(2**16 - 1)
      stream_ctxs
    end
    it 'should send' do
      Connection.send(io, frame3, send_window3, stream_ctxs3, data_buffer)
      expect(io.string).to eq ''
      expect(send_window3.length).to eq 2**16 - 1
      expect(stream_ctxs3.values.map(&:send_window).map(&:length)).to eq [2**16 - 1, 0]
      expect(data_buffer.length).to eq 1
    end

    let(:frame4) do
      Frame::Data.new(false, 2, 'Hello, world!', 'Howdy!')
    end
    let(:send_window4) do
      send_window = Window.new
      send_window.consume!(2**16 - 1)
      send_window
    end
    let(:stream_ctxs4) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end
    it 'should send' do
      Connection.send(io, frame4, send_window4, stream_ctxs4, data_buffer)
      expect(io.string).to eq ''
      expect(send_window4.length).to eq 0
      expect(stream_ctxs4.values.map(&:send_window).map(&:length)).to eq [2**16 - 1, 2**16 - 1]
      expect(data_buffer.length).to eq 1
    end
  end
end
