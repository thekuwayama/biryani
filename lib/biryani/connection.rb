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
      @data_buffer = DataBuffer.new
    end

    # @param io [IO]
    def serve(io)
      self.class.read_http2_magic(io)

      io.write(Frame::Settings.new(false, []).to_binary_s)
      io.flush

      loop do
        recv_frame = Frame.read(io)
        dispatch(recv_frame).each do |frame|
          io.write(frame.to_binary_s)
        end

        txs = @stream_ctxs.values.map(&:tx)
        until txs.empty?
          _, send_frame = Ractor.select(*txs)
          send_frame = send_frame.encode(@encoder) if send_frame.is_a?(Frame::RawHeaders)
          self.class.send(io, send_frame, @send_window, @stream_ctxs, @data_buffer)
        end

        # TODO: close connection
      end
    end

    # @param frame [Object]
    #
    # @return [Array<Object>] frames
    # rubocop: disable Metrics/AbcSize
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
          settings_ack = self.class.handle_settings(frame)
          return [settings_ack] unless settings_ack.nil?

          []
        when FrameType::PING
          ping_ack = self.class.handle_ping(frame)
          return [ping_ack] unless ping_ack.nil?

          []
        when FrameType::GOAWAY
          # TODO
          []
        when FrameType::WINDOW_UPDATE
          self.class.handle_window_update(frame, @send_window, @stream_ctxs)
          @data_buffer.take!(@send_window, @stream_ctxs)
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

        []
      end
    end
    # rubocop: enable Metrics/AbcSize
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/MethodLength
    # rubocop: enable Metrics/PerceivedComplexity

    # @return [Boolean]
    def closed?
      false
    end

    # @param io [IO]
    # @param frame [Object]
    # @param send_window [Window]
    # @param stream_ctxs [Hash<Integer, StreamContext>]
    # @param data_buffer [DataBuffer]
    def self.send(io, frame, send_window, stream_ctxs, data_buffer)
      if frame.f_type != FrameType::DATA
        io.write(frame.to_binary_s)
        return
      end

      data = frame
      if sendable?(data, send_window, stream_ctxs)
        io.write(data.to_binary_s)
        send_window.consume!(data.length)
        stream_ctxs[data.stream_id].send_window.consume!(data.length)
        return
      end

      data_buffer << data
    end

    # @param io [IO]
    def self.read_http2_magic(io)
      s = io.read(CONNECTION_PREFACE_LENGTH)
      raise 'protocol_error' if s != CONNECTION_PREFACE # TODO: send error
    end

    # @param window_update [WindowUpdate]
    # @param send_window [Window]
    # @param stream_ctxs [Hash<Integer, StreamContext>]
    def self.handle_window_update(window_update, send_window, stream_ctxs)
      if window_update.stream_id.zero?
        send_window.increase!(window_update.window_size_increment)
      else
        stream_ctxs[window_update.stream_id].send_window.increase!(window_update.window_size_increment)
      end
    end

    # @param ping [Ping]
    #
    # @return [Ping, nil]
    def self.handle_ping(ping)
      Frame::Ping.new(true, ping.opaque) unless ping.ack?
    end

    # @param settings [Settings]
    #
    # @return [Settings, nil]
    def self.handle_settings(settings); end

    # @param data [Data]
    # @param send_window [Window]
    # @param stream_ctxs [Hash<Integer, StreamContext>]
    #
    # @return [Boolean]
    def self.sendable?(data, send_window, stream_ctxs)
      length = data.length
      stream_id = data.stream_id
      send_window.available?(length) && stream_ctxs[stream_id].send_window.available?(length)
    end
  end
end
