require_relative 'frame'
require_relative 'stream'

module Biryani
  class Connection
    CONNECTION_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".freeze
    CONNECTION_PREFACE_LENGTH = CONNECTION_PREFACE.length
    private_constant :CONNECTION_PREFACE, :CONNECTION_PREFACE_LENGTH

    def initialize
      @streams = {}
      @last_stream_id = 0
    end

    # @param io [IO]
    def serve(io)
      self.class.read_http2_magic(io)

      wport = Writer.new.loop
      # TODO: write Frame::Settings via wport

      loop do
        frame = Frame.read(io)
        handle(frame, wport)
      end
    end

    # @param io [IO]
    def self.read_http2_magic(io)
      s = io.read(CONNECTION_PREFACE_LENGTH)
      abort 'protocol_error' if s != CONNECTION_PREFACE # TODO: send error
    end

    class Writer
      def initialize; end

      # @return [Ractor::Port]
      def loop
        Ractor.new do
          loop do
            io, f = Ractor.receive
            io.write(f) # TODO: check window
          end
        end
      end
    end

    # @param frame [Object]
    # @param wport [Ractor::Port]
    def handle(frame, wport)
      stream_id = frame.strea_id
      typ = frame.f_type
      if stream_id.zero?
        case typ
        when FrameType::DATA, FrameType::HEADERS, FrameType::PRIORITY, FrameType::RST_STREAM, FrameType::PUSH_PROMISE, FrameType::CONTINUATION
          abort 'protocol_error' # TODO: send error
        when FrameType::SETTINGS
          # TODO
        when FrameType::PING
          # TODO
        when FrameType::GOAWAY
          # TODO
        when FrameType::WINDOW_UPDATE
          # TODO
        end
      else
        if [FrameType::SETTINGS, FrameType::PING, FrameType::GOAWAY].include?(typ)
          abort 'protocol_error' # TODO: send error
        end

        if (stream = @streams[stream_id])
          stream.transition_state!(frame, :recv)
          @streams.delete(stream_id) if stream.closed?

          stream.rport << [frame, wport]
        else
          @streams[stream_id] = Stream.new(stream_id)
          @last_stream_id = [stream_id, @last_stream_id].max
        end
      end
    end
  end
end
