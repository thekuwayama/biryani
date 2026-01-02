require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_headers' do
    let(:headers) do
      Frame::Headers.new(true, false, 2, nil, nil, 'this is dummy', nil)
    end
    let(:ctx) do
      StreamContext.new(2, 65_535, 65_535, do_nothing_proc)
    end
    let(:decoder) do
      HPACK::Decoder.new(4_096)
    end
    it 'should handle' do
      expect(Connection.handle_headers(headers, ctx, decoder)).to eq nil
      expect(ctx.fragment.string).to eq 'this is dummy'
    end
  end
end
