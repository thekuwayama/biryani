module Biryani
  class Stream
    attr_accessor :rx

    # @param tx [Ractor::Port]
    # @param stream_id [Integer]
    # @param proc [Proc]
    def initialize(tx, stream_id, proc)
      @rx = Ractor.new(tx, stream_id, proc) do |tx, stream_id, proc|
        unless (req = Ractor.recv).nil?
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
            # the Connection has already finished, so discard the response
          end
        end
      end
    end
  end
end
