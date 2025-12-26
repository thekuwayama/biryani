module Biryani
  class Stream
    attr_accessor :rx

    # @param stream_id [Integer]
    # @param tx [Ractor] port
    # @param err [Ractor] port
    def initialize(stream_id, tx, err)
      @rx = Ractor.new(stream_id, tx, err) do |stream_id, tx, _err|
        _ = Ractor.receive

        tx << Frame::RawHeaders.new(true, false, stream_id, nil, nil, [[':status', '200']], nil)
        tx << Frame::Data.new(true, stream_id, 'Hello, world!', nil)
      end
    end
  end
end
