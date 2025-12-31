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
      Frame::Headers.new(true, true, 2, nil, nil, 'this is dummy'.b, nil)
    end
    let(:send_window1) do
      Window.new(65_535)
    end
    let(:streams_ctx1) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx
    end
    it 'should send' do
      streams_ctx1[2].state.transition!(headers1, :recv)
      Connection.send_headers(io, 2, "\x88".b, false, 16_384, streams_ctx1)
      Connection.send_data(io, 2, 'Hello, world!'.b, send_window1, 16_384, streams_ctx1, data_buffer)
      expect(io.string.force_encoding(Encoding::ASCII_8BIT)).to eq "\x00\x00\x01\x01\x04\x00\x00\x00\x02\x88\x00\x00\x0d\x00\x01\x00\x00\x00\x02Hello, world!".b
      expect(send_window1.length).to eq 65_535 - 13
      expect(streams_ctx1[1].send_window.length).to eq 65_535
      expect(streams_ctx1[2].send_window.length).to eq 65_535 - 13
      expect(data_buffer.length).to eq 0
    end

    let(:headers2) do
      Frame::Headers.new(true, true, 1, nil, nil, 'this is dummy', nil)
    end
    let(:send_window2) do
      Window.new(65_535)
    end
    let(:streams_ctx2) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx
    end
    it 'should send' do
      streams_ctx2[1].state.transition!(headers2, :recv)
      Connection.send_headers(io, 1, "\x88".b, true, 16_384, streams_ctx2)
      expect(io.string.force_encoding(Encoding::ASCII_8BIT)).to eq "\x00\x00\x01\x01\x05\x00\x00\x00\x01\x88".b
      expect(send_window2.length).to eq 65_535
      expect(streams_ctx2[1].send_window.length).to eq 65_535
      expect(streams_ctx2[2].send_window.length).to eq 65_535
      expect(data_buffer.length).to eq 0
    end

    let(:headers3) do
      Frame::Headers.new(true, true, 2, nil, nil, 'this is dummy', nil)
    end
    let(:send_window3) do
      Window.new(65_535)
    end
    let(:streams_ctx3) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx[2].send_window.consume!(65_535)
      streams_ctx
    end
    it 'should send' do
      streams_ctx3[2].state.transition!(headers3, :recv)
      Connection.send_data(io, 2, 'Hello, world!'.b, send_window3, 16_384, streams_ctx3, data_buffer)
      expect(io.string.force_encoding(Encoding::ASCII_8BIT)).to eq ''.b
      expect(send_window3.length).to eq 65_535
      expect(streams_ctx3[1].send_window.length).to eq 65_535
      expect(streams_ctx3[2].send_window.length).to eq 0
      expect(data_buffer.length).to eq 1
    end

    let(:headers4) do
      Frame::Headers.new(true, true, 2, nil, nil, 'this is dummy', nil)
    end
    let(:send_window4) do
      send_window = Window.new(65_535)
      send_window.consume!(65_535)
      send_window
    end
    let(:streams_ctx4) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx
    end
    it 'should send' do
      streams_ctx4[2].state.transition!(headers4, :recv)
      Connection.send_data(io, 2, 'Hello, world!'.b, send_window4, 16_384, streams_ctx4, data_buffer)
      expect(io.string.force_encoding(Encoding::ASCII_8BIT)).to eq ''.b
      expect(send_window4.length).to eq 0
      expect(streams_ctx4[1].send_window.length).to eq 65_535
      expect(streams_ctx4[2].send_window.length).to eq 65_535
      expect(data_buffer.length).to eq 1
    end
  end
end
