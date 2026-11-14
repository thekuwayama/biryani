module Biryani
  class Stream
    attr_accessor :rx

    # @param tx [Ractor::Port]
    # @param stream_id [Integer]
    # @param proc [Proc]
    # @param workers [Array<Ractor>, nil]
    def initialize(tx, stream_id, proc, workers = nil)
      @rx = if workers
              PoolDispatcher.new(workers, tx, stream_id, proc)
            else
              Ractor.new(tx, stream_id, proc) do |tx_, stream_id_, proc_|
                Stream.handle(Ractor.recv, stream_id_, tx_, proc_)
              end
            end
    end

    # @return [Ractor]
    def self.spawn_worker
      Ractor.new do
        loop do
          req, stream_id, tx, proc = Ractor.recv
          Stream.handle(req, stream_id, tx, proc)
        end
      end
    end

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

    class PoolDispatcher
      # @param workers [Array<Ractor>]
      # @param tx [Ractor::Port]
      # @param stream_id [Integer]
      # @param proc [Proc]
      def initialize(workers, tx, stream_id, proc)
        @workers = workers
        @tx = tx
        @stream_id = stream_id
        @proc = proc
      end

      # PoolDispatcher has the same #send interface as Ractor.
      #
      # @param req [HTTP::Request]
      # @param move [Boolean]
      def send(req, move: false)
        @workers.sample.send([req, @stream_id, @tx, @proc], move: move)
      end

      alias << send
    end
  end
end
