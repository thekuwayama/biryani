require_relative 'spec_helper'

RSpec.describe HTTPRequestBuilder do
  context 'field' do
    let(:builder) do
      HTTPRequestBuilder.new
    end
    it 'should field' do
      expect(builder.field('key', 'value')).to eq nil
    end
    it 'should not field' do
      expect(builder.field('KEY', 'VALUE')).to be_kind_of ConnectionError
      expect(builder.field(':key', 'value')).to be_kind_of ConnectionError
      expect(builder.field(':path', '')).to be_kind_of ConnectionError
      expect(builder.field('connection', 'keep-alive')).to be_kind_of ConnectionError
      expect(builder.field(':authority', 'localhost:8888')).to eq nil
      expect(builder.field(':authority', 'localhost:8888')).to be_kind_of ConnectionError
    end
  end

  context 'http_request' do
    it 'should build' do
      expect(HTTPRequestBuilder.http_request({ ':method' => 'GET', ':scheme' => 'http', ':path' => '/', ':authority' => 'localhost:8888' }, '')).to be_kind_of HTTPRequest
    end
    it 'should not build' do
      expect(HTTPRequestBuilder.http_request({ ':scheme' => 'http', ':path' => '/', ':authority' => 'localhost:8888' }, '')).to be_kind_of ConnectionError
      expect(HTTPRequestBuilder.http_request({ ':method' => 'GET', ':scheme' => 'http', ':path' => '/', ':authority' => 'localhost:8888', 'content-length' => '0' }, '1')).to be_kind_of ConnectionError
    end
  end

  context 'cookie' do
    let(:request) do
      builder = HTTPRequestBuilder.new
      builder.fields({ ':method' => 'GET', ':scheme' => 'http', ':path' => '/', ':authority' => 'localhost:8888' })
      builder.field('cookie', 'a=1')
      builder.field('cookie', 'b=2')
      builder.field('cookie', 'c=3')
      builder.field('cookie', 'd=4')
      builder.build('')
    end
    it 'should field' do
      expect(request.fields['cookie']).to eq ['a=1; b=2; c=3; d=4']
    end
  end
end
