require_relative 'frame'
require_relative 'state'

module Biryani
  class Stream
    attr_accessor :rx

    Bucket = Struct.new(:fields, :data)

    # rubocop: disable Metrics/AbcSize
    def initialize
      @state = State.new
      @rx = Ractor.new do
        decoder = HPACK::Decoder.new(4096)
        encoder = HPACK::Encoder.new(4096)
        bucket = Bucket.new(fields: [], data: '')

        loop do
          frame, tx = Ractor.receive

          case frame.f_type
          when FrameType::DATA
            bucket.data += frame.data

            if frame.end_stream?
              # TODO: Hello, world!
              tx << Frame::Headers.new(true, false, frame.stream_id, nil, nil, encoder.encode([[':status', '200']]), nil)
              tx << Frame::Data.new(true, frame.stream_id, 'Hello, world!', nil)
              break
            end
          when FrameType::HEADERS
            fields = decoder.decode(frame.fragment)
            bucket.fields += fields

            if frame.end_stream?
              # TODO: Hello, world!
              tx << Frame::Headers.new(true, false, frame.stream_id, nil, nil, encoder.encode([[':status', '200']]), nil)
              tx << Frame::Data.new(true, frame.stream_id, 'Hello, world!', nil)
              break
            end

            # TODO: other FrameType
          end
        end
      end
    end
    # rubocop: enable Metrics/AbcSize

    # @param frame [Object]
    # @param direction [:send, :recv]
    def transition_state!(frame, direction)
      @state.transition!(frame, direction)
    end

    # @return [Boolean]
    def closed?
      @state == closed
    end
  end
end
