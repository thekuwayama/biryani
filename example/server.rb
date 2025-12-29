#!/usr/bin/env ruby

$LOAD_PATH << "#{__dir__}/../lib"

require 'socket'
require 'biryani'

port = ARGV[0] || 8888
socket = TCPServer.new(port)

server = Biryani::Server.new(
  Ractor.shareable_proc do |_, res|
    res.status = 200
    res.content = 'Hello, world!'
    res
  end
)
server.run(socket)

# $ bundle exec ruby example/server.rb
# $ curl -v --http2-prior-knowledge http://localhost:8888
