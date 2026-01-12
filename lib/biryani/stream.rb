module Biryani
  class Stream
    attr_accessor :rx

    # @param tx [Port]
    # @param stream_id [Integer]
    # @param proc [Proc]
    def initialize(tx, stream_id, proc)
      @rx = Ractor.new(tx, stream_id, proc) do |tx, stream_id, proc|
        unless (req = Ractor.recv).nil?
          res = HTTPResponse.new(0, {}, '')

          proc.call(req, res)
          tx.send([res, stream_id], move: true)
        end
      end
    end
  end
end
