require_relative 'spec_helper'

RSpec.describe Server do
  before do
    @tcpserver = TCPServer.open(PORT)

    Ractor.new(@tcpserver) do |socket|
      server = Server.new(
        Ractor.shareable_proc do |_, res|
          res.status = 200
          res.content = 'OK'
        end
      )

      server.run(socket)
    end
  end

  let(:junit_report_file_path) do
    Dir.mkdir(JUNIT_REPORT_DIR) unless Dir.exist?(JUNIT_REPORT_DIR)

    "#{JUNIT_REPORT_DIR}/h2spec.xml"
  end

  let(:client) do
    which('h2spec')

    "h2spec --port #{PORT} --verbose --junit-report #{junit_report_file_path}"
  end

  after do
    @tcpserver.close
  end

  it 'should run' do
    system(client)
  end
end
