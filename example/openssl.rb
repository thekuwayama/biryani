#!/usr/bin/env ruby

$LOAD_PATH << "#{__dir__}/../lib"

require 'openssl'
require 'socket'
require 'biryani'

port = ARGV[0] || 4433

ctx = OpenSSL::SSL::SSLContext.new
ctx.cert = Ractor.make_shareable(OpenSSL::X509::Certificate.new(File.read("#{__dir__}/../fixtures/server.crt")))
ctx.key = Ractor.make_shareable(OpenSSL::PKey::RSA.new(File.read("#{__dir__}/../fixtures/server.key")))
socket = OpenSSL::SSL::SSLServer.new(TCPServer.new(port), ctx)

server = Biryani::Server.new(
  # @param _req [Biryani::HTTP::Request]
  # @param res [Biryani::HTTP::Response]
  Ractor.shareable_proc do |_req, res|
    res.status = 200
    res.content = 'Hello, world!'
  end
)
server.run(socket)

# $ bundle exec ruby example/openssl.rb
# $ curl -v -k https://localhost:4433
# TODO: /Users/thekuwayama/biryani/lib/biryani/server.rb:19:in 'Ractor#send': can not move OpenSSL::X509::Certificate object. (Ractor::Error)
