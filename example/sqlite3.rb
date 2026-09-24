#!/usr/bin/env ruby

$LOAD_PATH << "#{__dir__}/../lib"

require 'json'
require 'socket'
require 'sqlite3'
require 'biryani'

# `sqlite3` is not Ractor-safe, so the main Ractor owns the database, and handlers send queries to it through DB_PORT.
#
#   +-- main Ractor ---------------------+           +-- stream Ractor (1 Ractor / stream) ------------+
#   |                                    |           |                                                 |
#   |  +-- DB -----------------------+   |           |  +-- handler -------------------------------+   |
#   |  | SQLite3::Database           |   |           |  | App.call(req, res)                       |   |
#   |  +-----------------------------+   |           |  |   DB.execute(sql, *binds)                |   |
#   |      ^                             |           |  |     |                                    |   |
#   |      | sql                         |           |  |     | sql                                |   |
#   |      |                             |           |  |     v                                    |   |
#   |    DB_PORT.receive <---------------+-----------+--+---- DB_PORT.send                         |   |
#   |    reply.send ---------------------+-----------+--+---> reply.receive                        |   |
#   |                                    |           |  +------------------------------------------+   |
#   |  Ractor.new(server, socket)        |           |                                                 |
#   +----+-------------------------------+           +-------------------------------------------------+
#        |                                                                                          ^
#        v                                                                                          |
#   +-- server Ractor ----------------------+       +-- connection Ractor (1 Ractor / connection) --+--+
#   |  server.run(socket)                   |       |  Stream.new(tx, stream_id, proc)              |  |
#   |    Ractor.new(socket.accept, @proc) --+------>|    Ractor.new(tx, stream_id, proc) -----------+  |
#   +---------------------------------------+       +--------------------------------------------------+
DB_PORT = Ractor::Port.new

module DB
  class Error < StandardError; end

  # @param sql [String]
  # @param binds [Array<Object>]
  #
  # @raise [DB::Error] if the query fails on the main Ractor
  #
  # @return [Array<Hash>] rows
  # @return [Integer] changes
  def self.execute(sql, *binds)
    reply = Ractor::Port.new
    DB_PORT.send([sql, binds, reply])
    case reply.receive
    in [:ok, rows, changes]
      [rows, changes]
    in [:error, klass, message]
      raise Error, "#{klass}: #{message}"
    end
  end

  # @param path [String]
  def self.serve(path)
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    db.execute('CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT);')

    loop do
      sql, binds, reply = DB_PORT.receive
      begin
        rows = db.execute(sql, binds)
        reply.send([:ok, rows, db.changes])
      rescue StandardError => e
        reply.send([:error, e.class.name, e.message])
      end
    end
  end
end

module App
  # @param req [Biryani::HTTP::Request]
  # @param res [Biryani::HTTP::Response]
  def self.call(req, res)
    case req.method
    when 'POST'
      do_post(req, res)
    when 'GET'
      do_get(req, res)
    when 'PUT'
      do_put(req, res)
    when 'DELETE'
      do_delete(req, res)
    else
      respond(res, 405, { error: 'HTTP Method not allowed' })
    end
  end

  def self.do_post(req, res)
    name = parse_name(req.content)
    return respond(res, 400, { error: 'not found `name`' }) if name.nil?

    DB.execute('INSERT INTO users (name) VALUES (?);', name)
    respond(res, 201, { status: 'created' })
  end

  def self.do_get(req, res)
    if req.uri.path == '/'
      users, = DB.execute('SELECT id, name FROM users ORDER BY id;')
      return respond(res, 200, users)
    end

    users, = DB.execute('SELECT id, name FROM users WHERE id = ?;', user_id(req))
    return respond(res, 404, { error: 'not found' }) if users.empty?

    respond(res, 200, users.first)
  end

  def self.do_put(req, res)
    name = parse_name(req.content)
    return respond(res, 400, { error: 'not found `name`' }) if name.nil?

    _, changes = DB.execute('UPDATE users SET name = ? WHERE id = ?;', name, user_id(req))
    return respond(res, 404, { error: 'not found' }) if changes.zero?

    respond(res, 200, { status: 'ok' })
  end

  def self.do_delete(req, res)
    _, changes = DB.execute('DELETE FROM users WHERE id = ?;', user_id(req))
    return respond(res, 404, { error: 'not found' }) if changes.zero?

    respond(res, 200, { status: 'ok' })
  end

  # @param content [String]
  #
  # @return [String, nil]
  def self.parse_name(content)
    user = JSON.parse(content)
    user['name']&.to_s if user.is_a?(Hash)
  rescue JSON::ParserError
    nil
  end

  # @param req [Biryani::HTTP::Request]
  #
  # @return [Integer]
  def self.user_id(req)
    req.uri.path.split('/').reject(&:empty?).first.to_i
  end

  def self.respond(res, status, body)
    res.status = status
    res.fields['content-type'] = 'application/json'
    res.content = JSON.generate(body)
  end
end

port = ARGV[0] || 8888
path = ARGV[1] || '/tmp/sqlite3.db'
socket = TCPServer.new(port)

server = Biryani::Server.new(
  # @param req [Biryani::HTTP::Request]
  # @param res [Biryani::HTTP::Response]
  Ractor.shareable_proc do |req, res|
    App.call(req, res)
  end
)
Ractor.new(server, socket) { |s, sock| s.run(sock) }
DB.serve(path)

# $ bundle exec ruby example/sqlite3.rb
# $ curl -v --http2-prior-knowledge http://localhost:8888 -X POST -H "Content-Type: application/json" -d '{"name":"Alice","age":18}'
# $ curl -v --http2-prior-knowledge http://localhost:8888/
# $ curl -v --http2-prior-knowledge http://localhost:8888/1 -X PUT -H "Content-Type: application/json" -d '{"name":"Bob","age":20}'
# $ curl -v --http2-prior-knowledge http://localhost:8888/
# $ curl -v --http2-prior-knowledge http://localhost:8888/1 -X DELETE
