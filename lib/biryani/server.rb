module Biryani
  class Server
    def initialize; end

    # @param socket [Socket]
    def run(socket)
      loop do
        Ractor.new(socket.accept) do |io|
          conn = Connection.new
          conn.serve(io)
          io&.close
        end
      end
    end
  end
end
