require_relative 'spec_helper'

RSpec.describe Server do
  before do
    @tcpserver = TCPServer.open(PORT)

    Ractor.new(@tcpserver) do |socket|
      server = Server.new(
        Ractor.shareable_proc do |_req, res|
          res.status = 200
          res.content = 'OK'
        end
      )

      server.run(socket)
    end
  end

  let(:client) do
    which('h2spec')
    "h2spec --port #{PORT} --verbose"
  end

  after do
    @tcpserver.close
  end

  it 'should run' do
    system(client)
  end
end
