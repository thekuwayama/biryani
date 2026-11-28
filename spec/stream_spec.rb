require_relative 'spec_helper'

RSpec.describe Stream do
  def request(path)
    HTTP::Request.new('GET', URI("http://localhost#{path}"), {}, '')
  end

  def response
    _, res, stream_id = tx.receive
    [stream_id, res.status, res.content]
  end

  let(:proc) do
    Ractor.shareable_proc do |req, res|
      res.status = 200
      res.content = req.uri.path
    end
  end

  let(:tx) do
    Ractor::Port.new
  end

  shared_examples 'Ractor-like rx' do
    it 'should accept #send with move: true' do
      spawner.spawn(tx, 1).send(request('/1'), move: true)
      expect(response).to eq [1, 200, '/1']
    end

    it 'should accept #send without move:' do
      spawner.spawn(tx, 1).send(request('/1'))
      expect(response).to eq [1, 200, '/1']
    end

    it 'should accept #<<' do
      spawner.spawn(tx, 1) << request('/1')
      expect(response).to eq [1, 200, '/1']
    end
  end

  context Stream::Spawner do
    let(:spawner) do
      Ractor.make_shareable(Stream::Spawner.new(proc))
    end

    it 'should spawn the Stream Ractor' do
      expect(spawner.spawn(tx, 1)).to be_a Ractor
    end

    it_behaves_like 'Ractor-like rx'
  end

  context Stream::Pool do
    let(:spawner) do
      Ractor.make_shareable(Stream::Pool.new(proc, 1))
    end

    it 'should spawn the PoolDispatcher' do
      expect(spawner.spawn(tx, 1)).to be_a Stream::PoolDispatcher
    end

    it_behaves_like 'Ractor-like rx'

    it 'should handle the requests in the Worker Ractor' do
      spawner.spawn(tx, 1).send(request('/1'), move: true)
      spawner.spawn(tx, 3).send(request('/3'), move: true)

      expect([response, response]).to contain_exactly [1, 200, '/1'], [3, 200, '/3']
    end

    it 'should keep the Worker Ractor working after the Connection has finished' do
      closed = Ractor::Port.new
      closed.close
      spawner.spawn(closed, 1).send(request('/1'), move: true)

      spawner.spawn(tx, 3).send(request('/3'), move: true)
      expect(tx.receive).to match [:response, an_instance_of(HTTP::Response), 3]
    end
  end
end
