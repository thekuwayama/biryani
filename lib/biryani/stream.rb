module Biryani
  module Stream
    # @param req [HTTP::Request]
    # @param stream_id [Integer]
    # @param tx [Ractor::Port]
    # @param proc [Proc]
    def self.handle(req, stream_id, tx, proc)
      res = HTTP::Response.default
      begin
        proc.call(req, res)
        res.validate
      rescue StandardError => e
        puts e.backtrace
        res = HTTP::Response.internal_server_error
      end

      begin
        tx.send([:response, res, stream_id], move: true)
      rescue Ractor::ClosedError
        # The Connection has already finished, so discard the response.
        # Ractor::ClosedError is a StopIteration, so it MUST be rescued here not to break the loop of the Worker Ractor.
      end
    end

    class Spawner
      # @param proc [Proc]
      def initialize(proc)
        @proc = proc
      end

      # @param tx [Ractor::Port]
      # @param stream_id [Integer]
      #
      # @return [Ractor]
      def spawn(tx, stream_id)
        Ractor.new(tx, stream_id, @proc) do |tx_, stream_id_, proc_|
          Stream.handle(Ractor.recv, stream_id_, tx_, proc_)
        end
      end
    end

    class Pool
      # @param proc [Proc]
      # @param worker_count [Integer]
      def initialize(proc, worker_count)
        @workers = Array.new(worker_count) { Pool.spawn_worker(proc) }
      end

      # @param tx [Ractor::Port]
      # @param stream_id [Integer]
      #
      # @return [PoolDispatcher]
      def spawn(tx, stream_id)
        PoolDispatcher.new(@workers, tx, stream_id)
      end

      # @param proc [Proc]
      #
      # @return [Ractor]
      def self.spawn_worker(proc)
        Ractor.new(proc) do |proc_|
          loop do
            req, stream_id, tx = Ractor.recv
            Stream.handle(req, stream_id, tx, proc_)
          end
        end
      end
    end

    class PoolDispatcher
      # @param workers [Array<Ractor>]
      # @param tx [Ractor::Port]
      # @param stream_id [Integer]
      def initialize(workers, tx, stream_id)
        @workers = workers
        @tx = tx
        @stream_id = stream_id
      end

      # PoolDispatcher has the same #send interface as Ractor.
      #
      # @param req [HTTP::Request]
      # @param move [Boolean]
      def send(req, move: false)
        @workers.sample.send([req, @stream_id, @tx], move: move)
      end

      alias << send
    end
  end
end
