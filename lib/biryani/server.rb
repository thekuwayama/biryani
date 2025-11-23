require_relative 'connection'

module Biryani
  class Server
    def initialize; end

    # @param socket [Socket]
    def run(socket)
      loop do
        # TODO: ractor pool using Etc.nprocessors
        io = socket.accept

        conn = Connection.new
        conn.serve(io)
        io&.close
      end
    end
  end
end
