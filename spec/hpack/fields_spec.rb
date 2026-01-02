require_relative '../spec_helper'

RSpec.describe HPACK::Fields do
  context do
    let(:dynamic_table) do
      HPACK::DynamicTable.new(4096)
    end
    it 'should decode' do
      expect(HPACK::Fields.decode([<<HEXDUMP.split.join].pack('H*'),
  8286 8441 8a08 9d5c 0b81 70dc 79e7
  9e40 8721 eaa8 a449 8f57 88ea 52d6
  b0e8 3772 ff
HEXDUMP
                                  dynamic_table)).to eq [[':method', 'GET'], [':scheme', 'http'], [':path', '/'], [':authority', '127.0.0.1:8888'], ['connection', 'keep-alive']]
    end
  end
end
