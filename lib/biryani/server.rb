module Biryani
  class Server
    # @param proc [Proc]
    def initialize(proc)
      @proc = proc
    end

    # @param socket [Socket]
    def run(socket)
      loop do
        server = Ractor.new(@proc) do |proc|
          io = Ractor.recv
          conn = Connection.new(proc)
          conn.serve(io)
          io.close
        end

        server.send(socket.accept, move: true)
      end
    end
  end
end
