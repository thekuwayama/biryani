#!/usr/bin/env ruby

$LOAD_PATH << "#{__dir__}/../lib"

require 'optparse'
require 'uri'

INDEX_HTML = File.read("#{__dir__}/tiles/index.html").freeze
TILE_SIZE = 32

module App
  def self.call(path, query)
    case path
    when '/', '/index.html'
      [200, 'text/html; charset=utf-8', INDEX_HTML]
    when %r{^/tile/(\d+)/(\d+)\.svg$}
      do_tile(Regexp.last_match(1).to_i, Regexp.last_match(2).to_i, latency(query))
    else
      [404, 'text/plain', 'not found']
    end
  end

  def self.do_tile(x, y, latency)
    sleep(latency / 1000.0)
    hue = (x + y) * 12 % 360
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{TILE_SIZE}" height="#{TILE_SIZE}">
        <rect width="#{TILE_SIZE}" height="#{TILE_SIZE}" fill="hsl(#{hue}, 70%, 70%)"/>
      </svg>
    SVG
    [200, 'image/svg+xml', svg]
  end

  def self.latency(query)
    query = URI.decode_www_form(query || '').to_h
    query['latency'].to_i.clamp(0, 500)
  end
end

http1 = false
opt = OptionParser.new
opt.banner = 'Usage: tiles.rb [--http2 | --http1.1] [port]'
opt.on('--http2', 'serve over HTTP/2 with biryani (default)') { http1 = false }
opt.on('--http1.1', 'serve over HTTP/1.1 with WEBrick') { http1 = true }
opt.parse!
port = ARGV[0] || 8888

if http1
  require 'webrick'

  server = WEBrick::HTTPServer.new(Port: port)
  server.mount_proc('/') do |req, res|
    status, content_type, content = App.call(req.path, req.query_string)
    res.status = status
    res['content-type'] = content_type
    res['cache-control'] = 'no-store'
    res.body = content
  end
  trap('INT') { server.shutdown }
  server.start
else
  require 'socket'
  require 'biryani'

  socket = TCPServer.new(port)
  server = Biryani::Server.new(
    # @param req [Biryani::HTTP::Request]
    # @param res [Biryani::HTTP::Response]
    Ractor.shareable_proc do |req, res|
      status, content_type, content = App.call(req.uri.path, req.uri.query)
      res.status = status
      res.fields['content-type'] = content_type
      res.content = content
      res.fields['cache-control'] = 'no-store'
    end
  )
  server.run(socket)
end

# $ bundle exec ruby tiles.rb --http1.1 8889
# $ open http://localhost:8889/?latency=500
#
# $ bundle exec ruby tiles.rb --http2
# $ nginx -p "$PWD" -c nginx.conf -g 'daemon off; pid /dev/null; error_log stderr;'
# $ open https://localhost:4433/?latency=500
