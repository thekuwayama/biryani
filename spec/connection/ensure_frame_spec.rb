require_relative '../spec_helper'

RSpec.describe Connection do
  context 'ensure_frame' do
    let(:data) do
      Frame::Data.new(false, 2, 'Hello, world!', 'Howdy!')
    end
    it 'should ensure' do
      expect(Connection.ensure_frame(data, 0x01)).to eq data
    end

    let(:connection_error) do
      Error::ConnectionError.new(ErrorCode::NO_ERROR, 'debug')
    end
    it 'should ensure' do
      frame = Connection.ensure_frame(connection_error, 0x01)
      expect(frame).to be_kind_of Frame::Goaway
    end

    let(:stream_error) do
      Error::StreamError.new(ErrorCode::NO_ERROR, 0x01, 'msg')
    end
    it 'should ensure' do
      frame = Connection.ensure_frame(stream_error, 0x01)
      expect(frame).to be_kind_of Frame::RstStream
    end
  end
end
