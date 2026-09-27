## Usage

The examples run as follows:

```bash
$ cd /path/to/biryani/example/

$ bundle exec ruby hello_world.rb

$ curl --http2-prior-knowledge http://localhost:8888
Hello, world!
```

Web browsers do NOT support h2c. If you access the examples from a browser, you could use [nginx](https://nginx.org/en/docs/stream/ngx_stream_core_module.html) as a TLS termination proxy.

To terminate TLS, `nginx` requires PEM files of certificate and private key. For example, you could generate a locally-trusted certificate, `server.crt` and `server.key`, using [mkcert](https://github.com/FiloSottile/mkcert).

```bash
$ mkcert -install

$ mkcert -cert-file server.crt -key-file server.key localhost 127.0.0.1
```

Run `nginx` with [nginx.conf](nginx.conf) in this directory.

```bash
$ nginx -p "$PWD" -c nginx.conf -g 'daemon off; pid /dev/null; error_log stderr;'
```

Then open https://localhost:4433 in your browser.
