module Biryani
  class Stream
    attr_accessor :rx

    # @param tx [Port]
    # @param stream_id [Integer]
    # @param proc [Proc]
    def initialize(tx, stream_id, proc)
      @rx = Ractor.new(tx, stream_id, proc) do |tx, stream_id, proc|
        unless (req = Ractor.recv).nil?
          res = HTTPResponse.default

          begin
            proc.call(req, res)
            res.validate
          rescue StandardError => e
            puts e.backtrace
            res = HTTPResponse.internal_server_error
          end

          tx.send([res, stream_id], move: true)
        end
      end
    end
  end
end
