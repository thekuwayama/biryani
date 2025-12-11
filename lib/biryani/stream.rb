module Biryani
  class Stream
    attr_accessor :rx

    Bucket = Struct.new(:fields, :data)

    # @param tx [Ractor] port
    # rubocop: disable Metrics/AbcSize
    # rubocop: disable Metrics/BlockLength
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/MethodLength
    def initialize(tx)
      @rx = Ractor.new(tx) do |tx|
        bucket = Bucket.new(fields: [], data: '')

        loop do
          recv_frame = Ractor.receive

          case recv_frame.f_type
          when FrameType::SETTINGS, FrameType::PING, FrameType::GOAWAY
            raise 'protocol_error' # TODO: send error
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
            raise 'unreachable' # TODO: internal error
          when FrameType::PUSH_PROMISE
            # TODO
          when FrameType::WINDOW_UPDATE
            raise 'unreachable' # TODO: internal error
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
