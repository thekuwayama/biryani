module Biryani
  class Server
    # @param proc [Proc]
    def initialize(proc)
      @proc = proc
    end

    # @param socket [Socket]
    def run(socket)
      loop do
        Ractor.new(socket.accept, @proc) do |io, proc|
          conn = Connection.new(proc)
          conn.serve(io)
          io&.close
        end
      end
    end
  end
end
