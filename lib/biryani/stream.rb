module Biryani
  class Stream
    attr_accessor :rx

    # @param tx [Port]
    # @param stream_id [Integer]
    # @param proc [Proc]
    def initialize(tx, stream_id, proc)
      @rx = Ractor.new(tx, stream_id, proc) do |tx, stream_id, proc|
        req = Ractor.receive
        res = HTTPResponse.new(0, {}, '')

        begin
          proc.call(req, res)
        rescue StandardError
          tx << HTTPResponse.internal_error
        end

        tx << [res, stream_id]
      end
    end
  end
end
