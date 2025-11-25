require_relative 'frame'
require_relative 'stream'

module Biryani
  class Connection
    CONNECTION_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".freeze
    CONNECTION_PREFACE_LENGTH = CONNECTION_PREFACE.length

    private_constant :CONNECTION_PREFACE, :CONNECTION_PREFACE_LENGTH
    Ractor.make_shareable(CONNECTION_PREFACE)
    Ractor.make_shareable(CONNECTION_PREFACE_LENGTH)

    StreamTx = Struct.new(:stream, :tx)

    def initialize
      @streams = {}
      @encoder = HPACK::Encoder.new(4096)
      @decoder = HPACK::Decoder.new(4096)
    end

    # @param io [IO]
    def serve(io)
      self.class.read_http2_magic(io)

      io.write(Frame::Settings.new(false, []).to_binary_s)
      io.flush

      loop do
        recv_frame = Frame.read(io)
        dispatch(recv_frame)

        txs = @streams.values.map(&:tx)
        until txs.empty?
          _, send_frame = Ractor.select(*txs)
          send_frame = send_frame.encode(@encoder) if send_frame.is_a?(Frame::RawHeaders)
          io.write(send_frame.to_binary_s)
          @streams.delete(send_frame.stream_id)
        end

        # TODO: close connection
      end
    end

    # @param io [IO]
    def self.read_http2_magic(io)
      s = io.read(CONNECTION_PREFACE_LENGTH)
      abort 'protocol_error' if s != CONNECTION_PREFACE # TODO: send error
    end

    # @param frame [Object]
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/MethodLength
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
        elsif typ == FrameType::HEADERS
          frame = frame.decode(@decoder)
        end

        if (st = @streams[stream_id])
          stream = st.stream
          tx = st.tx
          stream.rx << [frame, tx]
          stream.transition_state!(frame, :recv)

          @streams.delete(stream_id) if stream.closed?
        else
          stream = Stream.new
          tx = channel
          stream.rx << [frame, tx]
          stream.transition_state!(frame, :send)

          @streams[stream_id] = StreamTx.new(stream, tx)
        end
      end
    end
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/MethodLength
    # rubocop: enable Metrics/PerceivedComplexity

    # @return [Ractor]
    def channel
      Ractor.new do
        loop do
          Ractor.yield Ractor.receive
        end
      end
    end

    # @return [Boolean]
    def closed?
      false
    end
  end
end
