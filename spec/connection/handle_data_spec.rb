require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_data' do
    let(:data) do
      Frame::Data.new(false, 2, 'Hello, world!', 'Howdy!')
    end
    let(:ctx) do
      StreamContext.new(2, 65_535, 65_535, do_nothing_proc)
    end
    let(:decoder) do
      HPACK::Decoder.new(4_096)
    end
    it 'should handle' do
      expect(Connection.handle_data(data, ctx, decoder)).to eq nil
      expect(ctx.content.string).to eq 'Hello, world!'
    end
  end
end
