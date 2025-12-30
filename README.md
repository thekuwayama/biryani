# biryani

[![Gem Version](https://badge.fury.io/rb/biryani.svg)](https://badge.fury.io/rb/biryani)
[![Actions Status](https://github.com/thekuwayama/biryani/actions/workflows/ci.yml/badge.svg)](https://github.com/thekuwayama/biryani/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE.txt)

`biryani` is an HTTP/2 server implemented using Ruby Ractor.

- https://datatracker.ietf.org/doc/rfc9113/
- https://datatracker.ietf.org/doc/rfc7541/


## Installation

The gem is available at [rubygems.org](https://rubygems.org/gems/biryani). You can install it the following:

```sh-session
$ gem install biryani
```


## Usage

This implementation intentionally provides a minimal API and delegates application-level responsibilities to your code.
Roughly, it works as follows:

```ruby
require 'socket'
require 'biryani'

port = ARGV[0] || 8888
socket = TCPServer.new(port)

server = Biryani::Server.new(
  # @param _req [Biryani::HTTPRequest]
  # @param res [Biryani::HTTPResponse]
  Ractor.shareable_proc do |_req, res|
    res.status = 200
    res.content = 'Hello, world!'
  end
)
server.run(socket)
```

```sh-session
$ curl --http2-prior-knowledge http://localhost:8888
Hello, world!
```


## License

`biryani` is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
