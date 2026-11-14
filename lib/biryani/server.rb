module Biryani
  class Server
    # @param proc [Proc]
    # @param workers [Integer, nil] the number of Worker Ractors shared by all connections.
    #                               If nil, a Stream Ractor is spawned for each stream.
    def initialize(proc, workers: nil)
      raise ArgumentError, 'workers must be nil or a positive Integer' unless workers.nil? || (workers.is_a?(::Integer) && workers.positive?)

      @proc = proc
      @workers = workers
    end

    # @param socket [Socket]
    def run(socket)
      workers = Ractor.make_shareable(Array.new(@workers) { Stream.spawn_worker }) unless @workers.nil?
      loop do
        io = socket.accept
        r = Ractor.new(@proc, workers) do |proc, workers_|
          io_ = Ractor.receive
          conn = Connection.new(proc, workers_)
          conn.serve(io_)
        ensure
          Biryani.ignore_peer_closed { io_&.close }
        end
        r.send(io, move: true)
      end
    end
  end
end
