module Biryani
  class Server
    # @param proc [Proc]
    # @param workers_count [Integer, nil]
    def initialize(proc, workers_count = nil)
      raise ArgumentError, 'workers_count MUST be nil or a positive Integer' \
        unless workers_count.nil? || (workers_count.is_a?(::Integer) && workers_count.positive?)

      @proc = proc
      @worker_count = workers_count
    end

    # @param socket [Socket]
    def run(socket)
      workers = Ractor.make_shareable(Array.new(@worker_count) { Stream.spawn_worker }) if pool?

      loop do
        io = socket.accept
        r = Ractor.new(@proc, workers) do |proc, workers_|
          io_ = Ractor.recv
          conn = Connection.new(proc, workers_)
          conn.serve(io_)
        ensure
          Biryani.ignore_peer_closed { io_&.close }
        end
        r.send(io, move: true)
      end
    end

    private

    # @return [Boolean]
    def pool?
      !@worker_count.nil?
    end
  end
end
