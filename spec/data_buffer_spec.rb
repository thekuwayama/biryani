require_relative 'spec_helper'

RSpec.describe DataBuffer do
  context 'take!' do
    let(:data_buffer) do
      DataBuffer.new
    end
    let(:send_window) do
      Window.new
    end
    let(:stream_ctxs) do
      { 1 => StreamContext.new, 2 => StreamContext.new }
    end

    it 'should handle' do
      expect(data_buffer.take!(send_window, stream_ctxs)).to eq []
    end
  end
end
