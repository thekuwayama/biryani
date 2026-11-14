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
      rx(1).send(request('/1'), move: true)
      expect(response).to eq [1, 200, '/1']
    end

    it 'should accept #send without move:' do
      rx(1).send(request('/1'))
      expect(response).to eq [1, 200, '/1']
    end

    it 'should accept #<<' do
      rx(1) << request('/1')
      expect(response).to eq [1, 200, '/1']
    end
  end

  context 'without workers' do
    def rx(stream_id)
      Stream.new(tx, stream_id, proc).rx
    end

    it 'should use the Stream Ractor as rx' do
      expect(rx(1)).to be_a Ractor
    end

    it_behaves_like 'Ractor-like rx'
  end

  context 'with workers' do
    let(:workers) do
      Ractor.make_shareable([Stream.spawn_worker])
    end

    def rx(stream_id)
      Stream.new(tx, stream_id, proc, workers).rx
    end

    it 'should use the PoolDispatcher as rx' do
      expect(rx(1)).to be_a Stream::PoolDispatcher
    end

    it_behaves_like 'Ractor-like rx'

    it 'should handle the requests in the Worker Ractor' do
      rx(1).send(request('/1'), move: true)
      rx(3).send(request('/3'), move: true)

      expect([response, response]).to contain_exactly [1, 200, '/1'], [3, 200, '/3']
    end

    it 'should keep the Worker Ractor working after the Connection has finished' do
      closed = Ractor::Port.new
      closed.close
      Stream.new(closed, 1, proc, workers).rx.send(request('/1'), move: true)

      rx(3).send(request('/3'), move: true)
      expect(tx.receive).to match [:response, an_instance_of(HTTP::Response), 3]
    end
  end
end
