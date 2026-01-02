require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_rst_stream' do
    let(:rst_stream) do
      Frame::RstStream.new(2, 0)
    end
    let(:ctx) do
      StreamContext.new(2, 65_535, 65_535, do_nothing_proc)
    end
    it 'should handle' do
      Connection.handle_rst_stream(rst_stream, ctx)
      expect(ctx.closed?).to eq true
    end
  end
end
