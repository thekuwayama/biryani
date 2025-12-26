require_relative 'spec_helper'

RSpec.describe FieldsBucket do
  context 'store' do
    let(:bucket) do
      FieldsBucket.new
    end
    it 'should store' do
      expect(bucket.store('key', 'value')).to eq nil
    end
    it 'should not store' do
      expect(bucket.store('KEY', 'VALUE')).to be_kind_of ConnectionError
      expect(bucket.store(':key', 'value')).to be_kind_of ConnectionError
      expect(bucket.store(':path', '')).to be_kind_of ConnectionError
      expect(bucket.store('connection-specific', 'value')).to be_kind_of ConnectionError
      expect(bucket.store(':authority', 'localhost:8888')).to eq nil
      expect(bucket.store(':authority', 'localhost:8888')).to be_kind_of ConnectionError
      expect(bucket.store('connection-specific', 'value')).to be_kind_of ConnectionError
    end
  end

  context 'http_request' do
    it 'should construct' do
      expect(FieldsBucket.http_request({ ':method' => 'GET', ':scheme' => 'http', ':path' => '/', ':authority' => 'localhost:8888' }, '')).to be_kind_of Net::HTTP::Get
    end
    it 'should not construct' do
      expect(FieldsBucket.http_request({ ':scheme' => 'http', ':path' => '/', ':authority' => 'localhost:8888' }, '')).to be_kind_of ConnectionError
      expect(FieldsBucket.http_request({ ':method' => 'GET', ':scheme' => 'http', ':path' => '/', ':authority' => 'localhost:8888', 'content-length' => '1' }, '')).to be_kind_of ConnectionError
    end
  end

  context 'cookie' do
    let(:bucket) do
      bucket = FieldsBucket.new
      bucket.merge!({ ':method' => 'GET', ':scheme' => 'http', ':path' => '/', ':authority' => 'localhost:8888' })
      bucket.store('cookie', 'a=1')
      bucket.store('cookie', 'b=2')
      bucket.store('cookie', 'c=3')
      bucket.store('cookie', 'd=4')
      bucket
    end
    let(:request) do
      bucket.http_request(StringIO.new)
    end
    it 'should store' do
      expect(request.fetch('cookie')).to eq 'a=1; b=2; c=3; d=4'
    end
  end
end
