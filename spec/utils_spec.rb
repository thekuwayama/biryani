require_relative 'spec_helper'

RSpec.describe Biryani do
  let(:data) do
    Frame::Data.new(false, 2, 'Hello, world!', 'Howdy!')
  end
  let(:connection_error) do
    ConnectionError.new(ErrorCode::NO_ERROR, 'debug')
  end
  let(:stream_error) do
    StreamError.new(ErrorCode::NO_ERROR, 1, 'debug')
  end

  context 'err?' do
    it 'should be not error' do
      expect(Biryani.err?(data)).to eq false
    end

    it 'should be error' do
      expect(Biryani.err?(connection_error)).to be true
    end

    it 'should be error' do
      expect(Biryani.err?(stream_error)).to be true
    end
  end

  context 'unwrap' do
    it 'should unwrap' do
      expect(Biryani.unwrap(data, 0x01)).to eq data
    end

    it 'should unwrap' do
      expect(Biryani.unwrap(connection_error, 0x01)).to be_kind_of Frame::Goaway
    end

    it 'should unwrap' do
      expect(Biryani.unwrap(stream_error, 0x01)).to be_kind_of Frame::RstStream
    end
  end
end
