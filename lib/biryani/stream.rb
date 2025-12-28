module Biryani
  class Stream
    attr_accessor :rx

    # @param tx [Port]
    # @param stream_id [Integer]
    def initialize(tx, stream_id)
      @rx = Ractor.new(tx, stream_id) do |tx, stream_id|
        _ = Ractor.receive

        tx << [200, {}, 'Hello, world!', stream_id]
      end
    end
  end
end
