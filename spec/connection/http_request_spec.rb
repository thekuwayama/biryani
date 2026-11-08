require_relative '../spec_helper'

RSpec.describe Connection do
  context 'http_request' do
    let(:decoder) do
      HPACK::Decoder.new(4_096)
    end

    it 'should return COMPRESSION_ERROR' do
      # invalid huffman padding
      obj = Connection.http_request(1, "\x82\x86\x84\x00\x82\xf8\xff\x00".b, '', decoder)
      expect(obj).to be_kind_of ConnectionError
      expect(obj.goaway(1).error_code).to eq ErrorCode::COMPRESSION_ERROR
    end

    it 'should return PROTOCOL_ERROR' do
      # missing :authority and host fields
      obj = Connection.http_request(1, "\x82\x86\x84".b, '', decoder)
      expect(obj).to be_kind_of StreamError
      expect(obj.rst_stream.error_code).to eq ErrorCode::PROTOCOL_ERROR
    end
  end
end
