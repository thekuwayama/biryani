require_relative 'spec_helper'

RSpec.describe DataBuffer do
  context 'take!' do
    let(:data_buffer1) do
      DataBuffer.new
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
    it 'should take' do
      expect(data_buffer1.take!(send_window1, streams_ctx1, 16_384).length).to eq 0
      expect(send_window1.length).to eq 65_535
      expect(streams_ctx1[1].send_window.length).to eq 65_535
      expect(streams_ctx1[2].send_window.length).to eq 65_535
    end

    let(:data_buffer2) do
      data_buffer = DataBuffer.new
      data_buffer.store(1, 'one')
      data_buffer.store(2, 'two')
      data_buffer
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
    it 'should take' do
      datas = data_buffer2.take!(send_window2, streams_ctx2, 16_384)
      expect(datas.length).to eq 2
      expect(datas.map(&:stream_id)).to eq [1, 2]
      expect(datas.map(&:data)).to eq %w[one two]
      expect(send_window2.length).to eq 65_535 - 6
      expect(streams_ctx2[1].send_window.length).to eq 65_535 - 3
      expect(streams_ctx2[2].send_window.length).to eq 65_535 - 3
    end

    let(:data_buffer3) do
      data_buffer = DataBuffer.new
      data_buffer.store(2, 'two')
      data_buffer
    end
    let(:send_window3) do
      Window.new(65_535)
    end
    let(:streams_ctx3) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx
    end
    it 'should take' do
      datas = data_buffer3.take!(send_window3, streams_ctx3, 16_384)
      expect(datas.length).to eq 1
      expect(datas.first.stream_id).to eq 2
      expect(datas.first.data).to eq 'two'
      expect(send_window3.length).to eq 65_535 - 3
      expect(streams_ctx3[1].send_window.length).to eq 65_535
      expect(streams_ctx3[2].send_window.length).to eq 65_535 - 3
    end

    let(:data_buffer4) do
      data_buffer = DataBuffer.new
      data_buffer.store(1, 'one')
      data_buffer.store(2, 'two')
      data_buffer
    end
    let(:send_window4) do
      Window.new(65_535)
    end
    let(:streams_ctx4) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx[1].send_window.consume!(65_535)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx
    end
    it 'should take' do
      datas = data_buffer4.take!(send_window4, streams_ctx4, 16_384)
      expect(datas.length).to eq 1
      expect(datas.first.stream_id).to eq 2
      expect(datas.first.data).to eq 'two'
      expect(send_window4.length).to eq 65_535 - 3
      expect(streams_ctx4[1].send_window.length).to eq 0
      expect(streams_ctx4[2].send_window.length).to eq 65_535 - 3
    end

    let(:data_buffer5) do
      data_buffer = DataBuffer.new
      data_buffer.store(1, 'one')
      data_buffer.store(2, 'two')
      data_buffer
    end
    let(:send_window5) do
      send_window = Window.new(65_535)
      send_window.consume!(65_535)
      send_window
    end
    let(:streams_ctx5) do
      streams_ctx = StreamsContext.new
      streams_ctx.new_context(1, 65_535, 65_535, do_nothing_proc)
      streams_ctx.new_context(2, 65_535, 65_535, do_nothing_proc)
      streams_ctx
    end
    it 'should take' do
      expect(data_buffer5.take!(send_window5, streams_ctx5, 16_384).length).to eq 0
      expect(send_window5.length).to eq 0
      expect(streams_ctx5[1].send_window.length).to eq 65_535
      expect(streams_ctx5[2].send_window.length).to eq 65_535
    end
  end

  context 'has?' do
    let(:data_buffer6) do
      data_buffer = DataBuffer.new
      data_buffer.store(1, 'one')
      data_buffer
    end
    it 'should take' do
      expect(data_buffer6.has?(1)).to eq true
      expect(data_buffer6.has?(2)).to eq false
    end
  end
end
