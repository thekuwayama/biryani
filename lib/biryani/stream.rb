module Biryani
  class Stream
    attr_accessor :rx

    Bucket = Struct.new(:fields, :data)

    # @param tx [Ractor] port
    # @param err [Ractor] port
    # rubocop: disable Metrics/AbcSize
    # rubocop: disable Metrics/BlockLength
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/MethodLength
    def initialize(tx, err)
      @rx = Ractor.new(tx, err) do |tx, err|
        bucket = Bucket.new(fields: [], data: '')

        loop do
          recv_frame = Ractor.receive

          typ = recv_frame.f_type
          stream_id = recv_frame.stream_id
          case typ
          when FrameType::SETTINGS, FrameType::PING, FrameType::GOAWAY
            err << Error::ConnectionError.new(ErrorCode::PROTOCOL_ERROR, "invalid frame type #{format('0x%02x', typ)} for stream identifier #{format('0x%02x', stream_id)}")
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
          when FrameType::PRIORITY
            self.class.handle_priority(recv_frame)
          when FrameType::RST_STREAM
            err << Error::ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'internal error')
          when FrameType::PUSH_PROMISE
            # TODO
          when FrameType::WINDOW_UPDATE
            err << Error::ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'internal error')
          when FrameType::CONTINUATION
            # TODO: check recv_frame.end_headers?
            bucket.fields += recv_frame.fields
          end
        end
      end
    end
    # rubocop: enable Metrics/AbcSize
    # rubocop: enable Metrics/BlockLength
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/MethodLength

    # @param _priority [Priority]
    def self.handle_priority(_priority)
      # https://datatracker.ietf.org/doc/html/rfc9113#section-5.3.2
    end
  end
end
