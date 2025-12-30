# biryani

[![Actions Status](https://github.com/thekuwayama/biryani/actions/workflows/ci.yml/badge.svg)](https://github.com/thekuwayama/biryani/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE.txt)

`biryani` is an HTTP/2 server implemented using Ruby Ractor.

- https://datatracker.ietf.org/doc/rfc9113/
- https://datatracker.ietf.org/doc/rfc7541/


## Getting started

You can install with:

```sh-session
$ gem install specific_install

$ gem specific_install git@github.com:thekuwayama/biryani.git
```

This implementation intentionally provides a minimal API and delegates application-level responsibilities to your code.
Roughly, it works as follows:

```ruby
require 'socket'
require 'biryani'

port = ARGV[0] || 8888
socket = TCPServer.new(port)

server = Biryani::Server.new(
  Ractor.shareable_proc do |_, res|
    res.status = 200
    res.content = 'Hello, world!'
  end
)
server.run(socket)
```


## License

`biryani` is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
