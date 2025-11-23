require_relative 'frame'
require_relative 'stream'

module Biryani
  class Connection
    CONNECTION_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".freeze
    CONNECTION_PREFACE_LENGTH = CONNECTION_PREFACE.length
    private_constant :CONNECTION_PREFACE, :CONNECTION_PREFACE_LENGTH

    StreamTx = Struct.new(:stream, :tx)

    def initialize
      @streams = {}
    end

    # @param io [IO]
    def serve(io)
      self.class.read_http2_magic(io)

      io.write(Frame::Settings.new(setting: []).to_binary_s)
      io.flush

      loop do
        recv_frame = Frame.read(io)
        dispatch(recv_frame)

        txs = @streams.values.map(&:tx)
        until txs.empty?
          _, send_frame = Ractor.select(*txs)
          io.write(send_frame.to_binary_s)
          @streams.delete(stream_id)
        end
      end
    end

    # @param io [IO]
    def self.read_http2_magic(io)
      s = io.read(CONNECTION_PREFACE_LENGTH)
      abort 'protocol_error' if s != CONNECTION_PREFACE # TODO: send error
    end

    # @param frame [Object]
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/PerceivedComplexity
    def dispatch(frame)
      stream_id = frame.stream_id
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

        if (st = @streams[stream_id])
          stream = st.stream
          stream.transition_state!(frame, :recv)
          @streams.delete(stream_id) if stream.closed?

          tx = st.tx
          stream.rx << [frame, tx]
        else
          stream = Stream.new
          tx = channel
          stream.rx << [frame, tx]

          @streams[stream_id] = StreamTx.new(stream, tx)
        end
      end
    end
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/PerceivedComplexity

    def channel
      Ractor.new do
        loop do
          Ractor.yield Ractor.receive
        end
      end
    end
  end
end
