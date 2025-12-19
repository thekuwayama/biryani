module Biryani
  class Stream
    attr_accessor :rx

    Bucket = Struct.new(:fields, :data)

    # @param tx [Ractor] port
    # @param err [Ractor] port
    def initialize(tx, err)
      @rx = Ractor.new(tx, err) do |tx, err|
        bucket = Bucket.new(fields: [], data: '')

        loop do
          recv_frame = Ractor.receive

          case recv_frame.f_type
          when FrameType::DATA
            bucket.data += recv_frame.data

            if recv_frame.end_stream?
              # TODO: Hello, world!
              tx << Frame::RawHeaders.new(true, false, recv_frame.stream_id, nil, nil, [[':status', '200']], nil)
              tx << Frame::Data.new(true, recv_frame.stream_id, 'Hello, world!', nil)
              break
            end
          when FrameType::HEADERS
            # TODO: check recv_frame.end_headers?
            bucket.fields += recv_frame.fields

            if recv_frame.end_stream?
              # TODO: Hello, world!
              tx << Frame::RawHeaders.new(true, false, recv_frame.stream_id, nil, nil, [[':status', '200']], nil)
              tx << Frame::Data.new(true, recv_frame.stream_id, 'Hello, world!', nil)
              break
            end
          when FrameType::PUSH_PROMISE
            # TODO
          when FrameType::CONTINUATION
            # TODO: check recv_frame.end_headers?
            bucket.fields += recv_frame.fields
          else
            err << ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'internal error')
          end
        end
      end
    end
  end
end
