require_relative 'connection'

module Biryani
  class Server
    def initialize; end

    # @param socket [Socket]
    def run(socket)
      connections = []
      loop do
        connections << Ractor.new(socket.accept) do |io|
          conn = Connection.new
          conn.serve(io)
          io&.close
        end
      end
      # TODO: close ractor
    end
  end
end
