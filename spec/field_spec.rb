require_relative 'spec_helper'

RSpec.describe HPACK::Field do
  context 'Field' do
    let(:dynamic_table) do
      HPACK::DynamicTable.new(4096)
    end

    it 'should encode' do
      expect(HPACK::Field.encode(':method', 'GET', dynamic_table)).to eq "\x82".b
      expect(HPACK::Field.encode(':status', '302', dynamic_table)).to eq "\x48\x82\x64\x02".b
      expect(HPACK::Field.encode('location', 'https://www.example.com', dynamic_table)).to eq "\x6e\x91\x9d\x29\xad\x17\x18\x63\xc7\x8f\x0b\x97\xc8\xe9\xae\x82\xae\x43\xd3".b
      expect(HPACK::Field.encode('custom-key', 'custom-header', dynamic_table)).to eq "\x40\x88\x25\xa8\x49\xe9\x5b\xa9\x7d\x7f\x89\x25\xa8\x49\xe9\x5a\x72\x8e\x42\xd9".b
    end
  end
end
