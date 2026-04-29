require_relative '../spec_helper'

RSpec.describe HTTP::Request do
  context 'trailers' do
    it 'should be empty' do
      expect(HTTP::Request.new('get', 'http://localhost:8888/', {}, '').trailers.empty?).to eq true
    end

    let(:req) do
      HTTP::Request.new('GET', 'http://localhost:8888/', { 'trailer' => %w[a b], 'a' => ['1'], 'b' => ['2'], 'c' => ['3'] }, '')
    end
    it 'should return' do
      expect(req.trailers['a']).to eq ['1']
      expect(req.trailers['b']).to eq ['2']
      expect(req.trailers['c']).to eq nil
    end
  end
end

RSpec.describe HTTP::RequestBuilder do
  context 'field' do
    let(:builder) do
      HTTP::RequestBuilder.new
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

  context 'build' do
    let(:request) do
      HTTP::RequestBuilder.build({ ':method' => ['get'], ':scheme' => ['http'], ':path' => ['/'], ':authority' => ['localhost:8888'], 'key' => ['value'] }, '')
    end
    it 'should build' do
      expect(request).to be_kind_of HTTP::Request
      expect(request.method).to eq 'GET'
      expect(request.uri).to eq URI('http://localhost:8888/')
      expect(request.fields).to eq({ 'key' => ['value'] })
      expect(request.content).to eq ''
    end
    it 'should not build' do
      expect(HTTP::RequestBuilder.build({ ':scheme' => ['http'], ':path' => ['/'], ':authority' => ['localhost:8888'] }, '')).to be_kind_of ConnectionError
      expect(HTTP::RequestBuilder.build({ ':method' => ['GET'], ':scheme' => ['http'], ':path' => ['/'], ':authority' => ['localhost:8888'], 'content-length' => ['0'] }, '1')).to be_kind_of ConnectionError
    end
  end

  context 'cookie' do
    let(:request) do
      builder = HTTP::RequestBuilder.new
      builder.fields([[':method', 'get'], [':scheme', 'http'], [':path', '/'], [':authority', 'localhost:8888']])
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
