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
      expect { builder.field('key', 'value') }.not_to raise_error
    end
    it 'should not field' do
      expect { builder.field('KEY', 'VALUE') }.to raise_error HTTP::Error::MalformedRequestError
      expect { builder.field(':key', 'value') }.to raise_error HTTP::Error::MalformedRequestError
      expect { builder.field(':path', '') }.to raise_error HTTP::Error::MalformedRequestError
      expect { builder.field('connection', 'keep-alive') }.to raise_error HTTP::Error::MalformedRequestError
      expect { builder.field(':authority', 'localhost:8888') }.not_to raise_error
      expect { builder.field(':authority', 'localhost:8888') }.to raise_error HTTP::Error::MalformedRequestError
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

    let(:request_with_host) do
      HTTP::RequestBuilder.build({ ':method' => ['GET'], ':scheme' => ['http'], ':path' => ['/'], 'host' => ['localhost:8888'] }, '')
    end
    it 'should build with host' do
      expect(request_with_host).to be_kind_of HTTP::Request
      expect(request_with_host.uri).to eq URI('http://localhost:8888/')
    end

    it 'should not build' do
      expect { HTTP::RequestBuilder.build({ ':scheme' => ['http'], ':path' => ['/'], ':authority' => ['localhost:8888'] }, '') }.to raise_error HTTP::Error::MalformedRequestError
      expect { HTTP::RequestBuilder.build({ ':method' => ['GET'], ':scheme' => ['http'], ':path' => ['/'], ':authority' => ['localhost:8888'], 'content-length' => ['4'] }, '123') }
        .to raise_error HTTP::Error::MalformedRequestError
      expect { HTTP::RequestBuilder.build({ ':method' => ['GET'], ':scheme' => ['http'], ':path' => ['/'] }, '') }.to raise_error HTTP::Error::MalformedRequestError
      expect { HTTP::RequestBuilder.build({ ':method' => ['GET'], ':scheme' => ['http'], ':path' => ['/'], ':authority' => ['localhost:8888'], 'host' => ['example.com'] }, '') }
        .to raise_error HTTP::Error::MalformedRequestError
      expect { HTTP::RequestBuilder.build({ ':method' => ['GET'], ':scheme' => ['http'], ':path' => ['/'], 'host' => ['localhost:8888', 'localhost:8888'] }, '') }
        .to raise_error HTTP::Error::MalformedRequestError
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
