#!/usr/bin/env ruby

$LOAD_PATH << "#{__dir__}/../lib"

require 'json'
require 'socket'
require 'sqlite3'
require 'biryani'

port = ARGV[0] || 8888
socket = TCPServer.new(port)

server = Biryani::Server.new(
  # rubocop: disable Metrics/BlockLength
  Ractor.shareable_proc do |req, res|
    def do_POST(req, res)
      user = JSON.parse(req.content)
      pp user
      if user.key?('name')
        res.status = 400
        res.content = 'not found `name`'
        return res
      end

      q = `INSERT INTO users (name) VALUES (?);`
      db.execute(q, user['name'].to_s)

      res.status = 200
      res.content = 'OK'
    end

    def do_GET(req, res)
      q = `SELECT * FROM users;`
      users = db.execute(q, id)

      res.status = 200
      res.content = '['
      res.content += users.map { |u| "{\"id\":#{u['id']},\"name\":\"#{u['name']}\"}" }.join(',')
      res.content += ']'
    end

    def do_PUT(req, res)
      id = req.uri.path.split('/').reject(&:empty?).first.to_i
      user = JSON.parse(req.content)
      if user.key?('name')
        res.status = 400
        res.content = 'not found `name`'
        return res
      end

      q = `UPDATE users SET name = ? WHERE id = ?;`
      db.execute(q, [user['name'].to_s, id])

      res.status = 200
      res.content = 'OK'
    end

    def do_DELETE(req, res)
      id = req.uri.path.split('/').reject(&:empty?).first.to_i

      q = `DELETE FROM users WHERE id = ?;`
      db.execute(q, id)

      res.status = 200
      res.content = 'OK'
    end

    db = SQLite3::Database.new('/tmp/sqlite3.db', flags: SQLite3::Constants::Open::FULLMUTEX | SQLite3::Constants::Open::READWRITE | SQLite3::Constants::Open::CREATE)
    db.results_as_hash = true
    q = `CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT);`
    db.execute(q)

    case req.method.upcase
    when 'POST'
      do_POST(req, res)
    when 'GET'
      do_GET(req, res)
    when 'PUT'
      do_PUT(req, res)
    when 'DELETE'
      do_DELETE(req, res)
    end
  end
  # rubocop: enable Metrics/BlockLength
)
server.run(socket)

# $ bundle exec ruby example/sqlite3.rb
# $ curl -v --http2-prior-knowledge http://localhost:8888 -X POST -H "Content-Type: application/json" -d '{"name":"Alice","age":18}'
# $ curl -v --http2-prior-knowledge http://localhost:8888/
# $ curl -v --http2-prior-knowledge http://localhost:8888/1 -X PUT -H "Content-Type: application/json" -d '{"name":"Bob","age":20}'
# $ curl -v --http2-prior-knowledge http://localhost:8888/
# $ curl -v --http2-prior-knowledge http://localhost:8888/1 -X DELETE
