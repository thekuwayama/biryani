require_relative '../spec_helper'

RSpec.describe Connection do
  context 'handle_headers' do
    let(:headers1) do
      Frame::Headers.new(true, false, 2, nil, nil, 'this is dummy', nil)
    end
    let(:ctx1) do
      StreamContext.new(2, 65_535, 65_535, do_nothing_proc, Ractor::Port.new)
    end
    let(:decoder) do
      HPACK::Decoder.new(4_096)
    end
    it 'should handle' do
      expect(Connection.handle_headers(headers1, ctx1, decoder)).to eq nil
      expect(ctx1.fragment).to eq 'this is dummy'
    end

    let(:headers2) do
      # invalid huffman padding
      Frame::Headers.new(true, true, 1, nil, nil, "\x82\x86\x84\x00\x82\xf8\xff\x00".b, nil)
    end
    let(:ctx2) do
      ctx = StreamContext.new(1, 65_535, 65_535, do_nothing_proc, Ractor::Port.new)
      ctx.state_transition!(headers2, :recv)
      ctx
    end
    it 'should not handle' do
      obj = Connection.handle_headers(headers2, ctx2, decoder)
      expect(obj).to be_kind_of ConnectionError
      expect(obj.goaway(1).error_code).to eq ErrorCode::COMPRESSION_ERROR
    end
  end
end
