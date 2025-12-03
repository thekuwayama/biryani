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
        state = State.new

        loop do
          recv_frame = Ractor.receive
          state.transition!(recv_frame, :recv)

          case recv_frame.f_type
          when FrameType::SETTINGS, FrameType::PING, FrameType::GOAWAY
            abort 'protocol_error' # TODO: send error
          when FrameType::DATA
            bucket.data += recv_frame.data

            if recv_frame.end_stream?
              # TODO: Hello, world!
              send_frame = Frame::RawHeaders.new(true, false, recv_frame.stream_id, nil, nil, [[':status', '200']], nil)
              state.transition!(send_frame, :send)
              tx << [send_frame, state.to_sym]
              send_frame = Frame::Data.new(true, recv_frame.stream_id, 'Hello, world!', nil)
              state.transition!(send_frame, :send)
              tx << [send_frame, state.to_sym]
              break
            end
          when FrameType::HEADERS
            bucket.fields += recv_frame.fields

            if recv_frame.end_stream?
              # TODO: Hello, world!
              send_frame = Frame::RawHeaders.new(true, false, recv_frame.stream_id, nil, nil, [[':status', '200']], nil)
              state.transition!(send_frame, :send)
              tx << [send_frame, state.to_sym]
              send_frame = Frame::Data.new(true, recv_frame.stream_id, 'Hello, world!', nil)
              state.transition!(send_frame, :send)
              tx << [send_frame, state.to_sym]
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
            self.class.handle_priority(recv_frame)
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
