require_relative '../spec_helper'

RSpec.describe Connection do
  context 'unwrap' do
    let(:data) do
      Frame::Data.new(false, 2, 'Hello, world!', 'Howdy!')
    end
    it 'should ensure' do
      expect(Connection.unwrap(data, 0x01)).to eq data
    end

    let(:connection_error) do
      ConnectionError.new(ErrorCode::NO_ERROR, 'debug')
    end
    it 'should ensure' do
      frame = Connection.unwrap(connection_error, 0x01)
      expect(frame).to be_kind_of Frame::Goaway
    end

    let(:stream_error) do
      StreamError.new(ErrorCode::NO_ERROR, 0x01, 'debug')
    end
    it 'should ensure' do
      frame = Connection.unwrap(stream_error, 0x01)
      expect(frame).to be_kind_of Frame::RstStream
    end
  end
end
