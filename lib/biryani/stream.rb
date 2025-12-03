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
      @state = State.new
      @rx = Ractor.new(tx) do |tx|
        bucket = Bucket.new(fields: [], data: '')

        loop do
          frame = Ractor.receive

          case frame.f_type
          when FrameType::SETTINGS, FrameType::PING, FrameType::GOAWAY
            abort 'protocol_error' # TODO: send error
          when FrameType::DATA
            bucket.data += frame.data

            if frame.end_stream?
              # TODO: Hello, world!
              tx << Frame::RawHeaders.new(true, false, frame.stream_id, nil, nil, [[':status', '200']], nil)
              tx << Frame::Data.new(true, frame.stream_id, 'Hello, world!', nil)
              break
            end
          when FrameType::HEADERS
            bucket.fields += frame.fields

            if frame.end_stream?
              # TODO: Hello, world!
              tx << Frame::RawHeaders.new(true, false, frame.stream_id, nil, nil, [[':status', '200']], nil)
              tx << Frame::Data.new(true, frame.stream_id, 'Hello, world!', nil)
              break
            end
          when FrameType::RST_STREAM
            # TODO
          when FrameType::PUSH_PROMISE
            # TODO
          when FrameType::WINDOW_UPDATE
            # TODO
          when FrameType::CONTINUATION
            # TODO
          when FrameType::PRIORITY
            self.class.handle_priority(frame)
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

    # @param frame [Object]
    # @param direction [:send, :recv]
    def transition_state!(frame, direction)
      @state.transition!(frame, direction)
    end

    # @return [Boolean]
    def closed?
      @state.closed?
    end
  end
end
