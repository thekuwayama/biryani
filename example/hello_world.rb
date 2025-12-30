#!/usr/bin/env ruby

$LOAD_PATH << "#{__dir__}/../lib"

require 'socket'
require 'biryani'

port = ARGV[0] || 8888
socket = TCPServer.new(port)

server = Biryani::Server.new(
  # @params _req [Biryani::HTTPRequest]
  # @params res [Biryani::HTTPResponse]
  Ractor.shareable_proc do |_req, res|
    res.status = 200
    res.content = 'Hello, world!'
  end
)
server.run(socket)

# $ bundle exec ruby example/hello_world.rb
# $ curl -v --http2-prior-knowledge http://localhost:8888
