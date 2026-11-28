module Biryani
  class Server
    # @param proc [Proc]
    # @param worker_count [Integer, nil]
    def initialize(proc, worker_count = nil)
      raise ArgumentError, 'worker_count MUST be nil or a positive Integer' \
        unless worker_count.nil? || (worker_count.is_a?(::Integer) && worker_count.positive?)

      @proc = proc
      @worker_count = worker_count
    end

    # @param socket [Socket]
    def run(socket)
      spawner = Ractor.make_shareable(pool? ? Stream::Pool.new(@proc, @worker_count) : Stream::Spawner.new(@proc))

      loop do
        io = socket.accept
        r = Ractor.new(spawner) do |spawner_|
          io_ = Ractor.recv
          conn = Connection.new(spawner_)
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
