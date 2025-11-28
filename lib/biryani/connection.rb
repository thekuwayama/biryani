require_relative 'frame'
require_relative 'stream'
require_relative 'window'

module Biryani
  class Connection
    CONNECTION_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".freeze
    CONNECTION_PREFACE_LENGTH = CONNECTION_PREFACE.length

    private_constant :CONNECTION_PREFACE, :CONNECTION_PREFACE_LENGTH
    Ractor.make_shareable(CONNECTION_PREFACE)
    Ractor.make_shareable(CONNECTION_PREFACE_LENGTH)

    def initialize
      @stream_ctxs = {} # Hash<Integer, StreamContext>
      @encoder = HPACK::Encoder.new(4096)
      @decoder = HPACK::Decoder.new(4096)
      @send_window = Window.new
      @recv_window = Window.new
    end

    # @param io [IO]
    def serve(io)
      self.class.read_http2_magic(io)

      io.write(Frame::Settings.new(false, []).to_binary_s)
      io.flush

      loop do
        recv_frame = Frame.read(io)
        dispatch(recv_frame)

        txs = @stream_ctxs.values.map(&:tx)
        until txs.empty?
          _, send_frame = Ractor.select(*txs)
          send_frame = send_frame.encode(@encoder) if send_frame.is_a?(Frame::RawHeaders)
          send(io, send_frame)
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
          handle_window_update(frame)
          # TODO: send buffering data
        end
      else
        if [FrameType::SETTINGS, FrameType::PING, FrameType::GOAWAY].include?(typ)
          abort 'protocol_error' # TODO: send error
        elsif typ == FrameType::HEADERS
          frame = frame.decode(@decoder)
        end

        ctx = @stream_ctxs[stream_id] || StreamContext.new
        stream = ctx.stream
        tx = ctx.tx
        stream.rx << [frame, tx]
        stream.transition_state!(frame, :recv)

        if stream.closed?
          @stream_ctxs.delete(stream_id)
        else
          @stream_ctxs[stream_id] = ctx
        end
      end
    end
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/PerceivedComplexity

    # @return [Boolean]
    def closed?
      false
    end

    # @param io [IO]
    # @param frame [Object]
    def send(io, frame)
      if frame.f_type != FrameType::DATA
        io.write(frame.to_binary_s)
        return
      end

      stream_id = frame.stream_id
      if @send_window.available?(frame.length) && @stream_ctxs[stream_id].send_window.available?(frame.length)
        io.write(frame.to_binary_s)
        @send_window.consume!(frame.length)
        @stream_ctxs[stream_id].send_window.consume!(frame.length)
        return
      end

      @stream_ctxs[stream_id].enqueue(frame)
    end

    def handle_window_update(frame)
      if frame.stream_id.zero?
        @send_window.increase!(frame.window_size_increment)
      else
        @stream_ctxs[frame.stream_id].send_window.consume!(frame.length)
      end
    end
  end
end
