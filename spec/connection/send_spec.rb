require_relative '../spec_helper'

RSpec.describe Connection do
  context 'send' do
    let(:io) do
      StringIO.new
    end
    let(:data_buffer) do
      DataBuffer.new
    end

    let(:headers1) do
      Frame::Headers.new(true, false, 2, nil, nil, 'this is dummy', nil)
    end
    let(:data1) do
      Frame::Data.new(true, 2, 'Hello, world!', 'Howdy!')
    end
    let(:send_window1) do
      Window.new
    end
    let(:streams_ctx1) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, do_nothing_proc)
      streams_ctx.new_context(2, do_nothing_proc)
      streams_ctx
    end
    it 'should send' do
      streams_ctx1[2].state.transition!(headers1, :recv)
      streams_ctx1[2].state.transition!(data1, :recv)
      Connection.send(io, headers1, send_window1, streams_ctx1, data_buffer)
      Connection.send(io, data1, send_window1, streams_ctx1, data_buffer)
      expect(io.string).to eq "\x00\x00\x0d\x01\x04\x00\x00\x00\x02this is dummy\x00\x00\x14\x00\x09\x00\x00\x00\x02\x06\x48\x65\x6c\x6c\x6f\x2c\x20\x77\x6f\x72\x6c\x64\x21\x48\x6f\x77\x64\x79\x21".b
      expect(send_window1.length).to eq 2**16 - 21
      expect(streams_ctx1[1].send_window.length).to eq 2**16 - 1
      expect(streams_ctx1[2].send_window.length).to eq 2**16 - 21
      expect(data_buffer.length).to eq 0
    end

    let(:headers2) do
      Frame::Headers.new(true, true, 1, nil, nil, 'this is dummy', nil)
    end
    let(:send_window2) do
      Window.new
    end
    let(:streams_ctx2) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, do_nothing_proc)
      streams_ctx.new_context(2, do_nothing_proc)
      streams_ctx
    end
    it 'should send' do
      streams_ctx2[1].state.transition!(headers2, :recv)
      Connection.send(io, headers2, send_window2, streams_ctx2, data_buffer)
      expect(io.string).to eq "\x00\x00\x0d\x01\x05\x00\x00\x00\x01\x74\x68\x69\x73\x20\x69\x73\x20\x64\x75\x6d\x6d\x79".b
      expect(send_window2.length).to eq 2**16 - 1
      expect(streams_ctx2[1].send_window.length).to eq 2**16 - 1
      expect(streams_ctx2[2].send_window.length).to eq 2**16 - 1
      expect(data_buffer.length).to eq 0
    end

    let(:headers3) do
      Frame::Headers.new(true, true, 2, nil, nil, 'this is dummy', nil)
    end
    let(:data3) do
      Frame::Data.new(false, 2, 'Hello, world!', 'Howdy!')
    end
    let(:send_window3) do
      Window.new
    end
    let(:streams_ctx3) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, do_nothing_proc)
      streams_ctx.new_context(2, do_nothing_proc)
      streams_ctx[2].send_window.consume!(2**16 - 1)
      streams_ctx
    end
    it 'should send' do
      streams_ctx3[2].state.transition!(headers3, :recv)
      Connection.send(io, data3, send_window3, streams_ctx3, data_buffer)
      expect(io.string).to eq ''
      expect(send_window3.length).to eq 2**16 - 1
      expect(streams_ctx3[1].send_window.length).to eq 2**16 - 1
      expect(streams_ctx3[2].send_window.length).to eq 0
      expect(data_buffer.length).to eq 1
    end

    let(:headers4) do
      Frame::Headers.new(true, true, 2, nil, nil, 'this is dummy', nil)
    end
    let(:data4) do
      Frame::Data.new(false, 2, 'Hello, world!', 'Howdy!')
    end
    let(:send_window4) do
      send_window = Window.new
      send_window.consume!(2**16 - 1)
      send_window
    end
    let(:streams_ctx4) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, do_nothing_proc)
      streams_ctx.new_context(2, do_nothing_proc)
      streams_ctx
    end
    it 'should send' do
      streams_ctx4[2].state.transition!(headers4, :recv)
      Connection.send(io, data4, send_window4, streams_ctx4, data_buffer)
      expect(io.string).to eq ''
      expect(send_window4.length).to eq 0
      expect(streams_ctx4[1].send_window.length).to eq 2**16 - 1
      expect(streams_ctx4[2].send_window.length).to eq 2**16 - 1
      expect(data_buffer.length).to eq 1
    end
  end
end
