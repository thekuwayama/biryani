require_relative 'spec_helper'

RSpec.describe Stream do
  def request(path)
    HTTP::Request.new('GET', URI("http://localhost#{path}"), {}, '')
  end

  let(:proc) do
    Ractor.shareable_proc do |req, res|
      res.status = 200
      res.content = req.uri.path
    end
  end

  context 'without workers' do
    it 'should handle the request in the Stream Ractor' do
      tx = Ractor::Port.new
      Stream.new(tx, 1, proc).rx.send(request('/1'), move: true)

      _, res, stream_id = tx.receive
      expect([stream_id, res.status, res.content]).to eq [1, 200, '/1']
    end
  end

  context 'with workers' do
    let(:workers) do
      Ractor.make_shareable([Stream.spawn_worker])
    end

    it 'should handle the requests in the Worker Ractor' do
      tx = Ractor::Port.new
      Stream.new(tx, 1, proc, workers).rx.send(request('/1'), move: true)
      Stream.new(tx, 3, proc, workers).rx.send(request('/3'), move: true)

      responses = [tx.receive, tx.receive].map { |_, res, stream_id| [stream_id, res.status, res.content] }
      expect(responses).to contain_exactly [1, 200, '/1'], [3, 200, '/3']
    end

    it 'should keep the Worker Ractor working after the Connection has finished' do
      closed = Ractor::Port.new
      closed.close
      Stream.new(closed, 1, proc, workers).rx.send(request('/1'), move: true)

      tx = Ractor::Port.new
      Stream.new(tx, 3, proc, workers).rx.send(request('/3'), move: true)
      expect(tx.receive).to match [:response, an_instance_of(HTTP::Response), 3]
    end
  end
end
