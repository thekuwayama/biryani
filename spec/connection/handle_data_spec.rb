require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_data' do
    let(:decoder) do
      HPACK::Decoder.new(4_096)
    end

    let(:recv_window1) do
      Window.new(65_535)
    end
    let(:streams_ctx1) do
      streams_ctx = StreamsContext.new(do_nothing_proc)
      streams_ctx.new_context(1, 65_535, 65_535)
      streams_ctx.new_context(2, 65_535, 65_535)
      streams_ctx
    end
    it 'should handle' do
      expect(Connection.handle_data(2, 'Hello, world!', recv_window1, streams_ctx1, decoder)).to eq []
      expect(streams_ctx1[2].content).to eq 'Hello, world!'
    end

    let(:recv_window2) do
      recv_window = Window.new(65_535)
      recv_window.consume!(65_535 / 2)
      recv_window
    end
    let(:streams_ctx2) do
      streams_ctx = StreamsContext.new(do_nothing_proc)
      streams_ctx.new_context(1, 65_535, 65_535)
      streams_ctx.new_context(2, 65_535, 65_535)
      streams_ctx[2].recv_window.consume!(65_535 / 2)
      streams_ctx
    end
    it 'should handle' do
      frames = Connection.handle_data(2, 'Hello, world!', recv_window2, streams_ctx2, decoder)
      expect(frames.map(&:f_type)).to eq [FrameType::WINDOW_UPDATE, FrameType::WINDOW_UPDATE]
      expect(frames.map(&:stream_id)).to eq [0, 2]
      expect(frames.map(&:window_size_increment)).to eq [65_535 / 2 + 13, 65_535 / 2 + 13]
      expect(streams_ctx2[2].content).to eq 'Hello, world!'
    end

    let(:recv_window3) do
      recv_window = Window.new(65_535)
      recv_window.consume!(65_535)
      recv_window
    end
    let(:streams_ctx3) do
      streams_ctx = StreamsContext.new(do_nothing_proc)
      streams_ctx.new_context(1, 65_535, 65_535)
      streams_ctx.new_context(2, 65_535, 65_535)
      streams_ctx
    end
    it 'should not handle' do
      expect(Connection.handle_data(2, 'Hello, world!', recv_window3, streams_ctx3, decoder)).to be_kind_of ConnectionError
    end
  end
end
