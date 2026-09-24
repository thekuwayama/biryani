#!/usr/bin/env ruby

$LOAD_PATH << "#{__dir__}/../lib"

require 'json'
require 'socket'
require 'ractor/keylockhash'
require 'ractor/lockvar'
require 'biryani'

# `Ractor::LockVar` and `Ractor::KeyLockHash` (ko1/ractor-sharing) are shareable, so every stream Ractor uses NEXT_ID and STORE directly.
# Each key of STORE is consistent on its own; `to_h` is not a snapshot of the whole map, and deleted keys keep their entries.
#
#   +-- stream Ractor (POST /) --------------+          +-- NEXT_ID ---------------------+
#   |  NEXT_ID.increment --------------------+--------->|  Ractor::LockVar               |
#   |  STORE[id] = value --------------------+-----+    +--------------------------------+
#   +----------------------------------------+     |
#                                                  |    +-- STORE -----------------------+
#   +-- stream Ractor (PUT /:id) ------------+     +--->|  Ractor::KeyLockHash           |
#   |  STORE.update(id) { ... } -------------+-----+    |  1 => "hoge"                   |
#   +----------------------------------------+          |  2 => "piyo"                   |
#                                                       +--------------------------------+
NEXT_ID = Ractor::LockVar.new(0) # plays the role of AUTOINCREMENT in SQL
STORE = Ractor::KeyLockHash.new

module App
  # @param req [Biryani::HTTP::Request]
  # @param res [Biryani::HTTP::Response]
  def self.call(req, res)
    case req.method
    when 'POST'
      do_post(req.content, res)
    when 'GET'
      req.uri.path == '/' ? do_list(res) : do_get(item_id(req), res)
    when 'PUT'
      do_put(item_id(req), req.content, res)
    when 'DELETE'
      do_delete(item_id(req), res)
    else
      respond(res, 405, { error: 'HTTP Method not allowed' })
    end
  end

  def self.do_post(value, res)
    id = NEXT_ID.increment
    STORE[id] = value
    respond(res, 201, { status: 'created', id: id })
  end

  def self.do_list(res)
    respond(res, 200, STORE.to_h.compact.keys.sort)
  end

  def self.do_get(id, res)
    value = STORE[id]
    return respond(res, 404, { error: 'not found' }) if value.nil?

    res.status = 200
    res.fields['content-type'] = 'text/plain'
    res.content = value
  end

  def self.do_put(id, value, res)
    updated = false
    STORE.update(id) do |old|
      next if old.nil?

      updated = true
      value
    end
    return respond(res, 404, { error: 'not found' }) unless updated

    respond(res, 200, { status: 'ok' })
  end

  def self.do_delete(id, res)
    return respond(res, 404, { error: 'not found' }) if STORE.delete(id).nil?

    respond(res, 200, { status: 'ok' })
  end

  # @param req [Biryani::HTTP::Request]
  #
  # @return [Integer]
  def self.item_id(req)
    req.uri.path.split('/').reject(&:empty?).first.to_i
  end

  def self.respond(res, status, body)
    res.status = status
    res.fields['content-type'] = 'application/json'
    res.content = JSON.generate(body)
  end
end

port = ARGV[0] || 8888
socket = TCPServer.new(port)

server = Biryani::Server.new(
  # @param req [Biryani::HTTP::Request]
  # @param res [Biryani::HTTP::Response]
  Ractor.shareable_proc do |req, res|
    App.call(req, res)
  end
)
server.run(socket)

# $ bundle exec ruby example/kv_store.rb
# $ curl -v --http2-prior-knowledge http://localhost:8888 -X POST -d 'hoge'
# $ curl -v --http2-prior-knowledge http://localhost:8888/
# $ curl -v --http2-prior-knowledge http://localhost:8888/1 -X PUT -d 'piyo'
# $ curl -v --http2-prior-knowledge http://localhost:8888/1
# $ curl -v --http2-prior-knowledge http://localhost:8888/1 -X DELETE
