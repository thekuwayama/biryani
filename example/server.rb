#!/usr/bin/env ruby

$LOAD_PATH << "#{__dir__}/../lib"

require 'socket'
require 'biryani'

port = ARGV[0] || 8888

server = TCPServer.new(port)
loop do
  socket = server.accept

  conn = Biryani::Connection.new
  conn.serve(socket)
  socket&.close
end

# $ bundle exec ruby example/server.rb
# $ curl -v --http2-prior-knowledge http://localhost:8888
