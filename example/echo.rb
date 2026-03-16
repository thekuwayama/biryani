#!/usr/bin/env ruby

$LOAD_PATH << "#{__dir__}/../lib"

require 'socket'
require 'biryani'

port = ARGV[0] || 8888
socket = TCPServer.new(port)

server = Biryani::Server.new(
  # @param req [Biryani::HTTP::Request]
  # @param res [Biryani::HTTP::Response]
  Ractor.shareable_proc do |req, res|
    res.status = 200
    res.content = if req.method.upcase == 'POST'
                    req.content
                  else
                    ''
                  end
  end
)
server.run(socket)

# $ bundle exec ruby example/echo.rb
# $ curl -v --http2-prior-knowledge http://localhost:8888 -X POST -d hi
