module Biryani
  class Server
    # @param proc [Proc]
    def initialize(proc)
      @proc = proc
    end

    # @param socket [Socket]
    def run(socket)
      loop do
        io = socket.accept
        r = Ractor.new(@proc) do |proc|
          io_ = Ractor.receive
          conn = Connection.new(proc)
          conn.serve(io_)
        ensure
          Biryani.ignore_peer_closed { io_&.close }
        end
        r.send(io, move: true)
      end
    end
  end
end
