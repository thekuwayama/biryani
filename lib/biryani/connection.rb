module Biryani
  module SettingsID
    SETTINGS_HEADER_TABLE_SIZE      = 0x0001
    SETTINGS_ENABLE_PUSH            = 0x0002
    SETTINGS_MAX_CONCURRENT_STREAMS = 0x0003
    SETTINGS_INITIAL_WINDOW_SIZE    = 0x0004
    SETTINGS_MAX_FRAME_SIZE         = 0x0005
    SETTINGS_MAX_HEADER_LIST_SIZE   = 0x0006
  end

  class Connection
    CONNECTION_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".freeze
    CONNECTION_PREFACE_LENGTH = CONNECTION_PREFACE.length

    private_constant :CONNECTION_PREFACE, :CONNECTION_PREFACE_LENGTH
    Ractor.make_shareable(CONNECTION_PREFACE)
    Ractor.make_shareable(CONNECTION_PREFACE_LENGTH)

    def initialize
      @max_streams = 0xffffffff
      @stream_ctxs = {} # Hash<Integer, StreamContext>
      @encoder = HPACK::Encoder.new(4_096)
      @decoder = HPACK::Decoder.new(4_096)
      @send_window = Window.new
      @recv_window = Window.new
      @data_buffer = DataBuffer.new
      @send_settings = self.class.default_settings # Hash<Integer, Integer>
      @recv_settings = self.class.default_settings # Hash<Integer, Integer>
    end

    # @param io [IO]
    def serve(io)
      self.class.read_http2_magic(io)
      self.class.do_send(io, Frame::Settings.new(false, []), true)

      loop do
        recv_frame = Frame.read(io)
        dispatch(recv_frame).each do |frame|
          self.class.do_send(io, frame, false)
        end

        send_loop(io)
        break if io.eof?
      end
    rescue Error::ConnectionError => e
      self.class.do_send(io, e.goaway(last_stream_id), true)
    rescue StandardError
      self.class.do_send(io, Frame::Goaway.new(last_stream_id, ErrorCode::INTERNAL_ERROR, 'internal error'), true)
    end

    # @param frame [Object]
    #
    # @return [Array<Object>] frames
    def dispatch(frame)
      if frame.stream_id.zero?
        handle_connection_frame(frame)
      else
        handle_stream_frame(frame).each do |f|
          stream_id = f.stream_id
          @stream_ctxs[stream_id].state.transition!(f, :send)
        end
      end
    end

    # @param frame [Object]
    #
    # @return [Array<Object>] frames
    # rubocop: disable Metrics/CyclomaticComplexity
    def handle_connection_frame(frame)
      typ = frame.f_type
      case typ
      when FrameType::DATA, FrameType::HEADERS, FrameType::PRIORITY, FrameType::RST_STREAM, FrameType::PUSH_PROMISE, FrameType::CONTINUATION
        raise Error::ConnectionError.new(ErrorCode::PROTOCOL_ERROR, "invalid frame type #{format('0x%02x', typ)} for stream identifier 0x00")
      when FrameType::SETTINGS
        pair = self.class.handle_settings(frame, @send_settings, @decoder)
        return [] if pair.nil?

        settings_ack, @max_streams = pair
        [settings_ack]
      when FrameType::PING
        ping_ack = self.class.handle_ping(frame)
        return [ping_ack] unless ping_ack.nil?

        []
      when FrameType::GOAWAY
        self.class.handle_goaway(frame)
        # TODO: logging error
        []
      when FrameType::WINDOW_UPDATE
        self.class.handle_window_update(frame, @send_window, @stream_ctxs)
        @data_buffer.take!(@send_window, @stream_ctxs)
      end
    end
    # rubocop: enable Metrics/CyclomaticComplexity

    # @param frame [Object]
    #
    # @return [Array<Object>] frames
    # rubocop: disable Metrics/AbcSize
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/PerceivedComplexity
    def handle_stream_frame(frame)
      stream_id = frame.stream_id
      typ = frame.f_type
      case typ
      when FrameType::SETTINGS, FrameType::PING, FrameType::GOAWAY
        raise Error::ConnectionError.new(ErrorCode::PROTOCOL_ERROR, "invalid frame type #{format('0x%02x', typ)} for stream identifier #{format('0x%02x', stream_id)}")
      when FrameType::DATA, FrameType::HEADERS, FrameType::PRIORITY, FrameType::CONTINUATION
        frame = frame.decode(@decoder) if typ == FrameType::HEADERS || FrameType::CONTINUATION
        ctx = @stream_ctxs[stream_id]
        raise Error::StreamError.new(ErrorCode::PROTOCOL_ERROR, stream_id, 'exceed max concurrent streams') if ctx.nil? && @stream_ctxs.values.filter(&:active?).length + 1 > @max_streams

        if ctx.nil?
          ctx = StreamContext.new
          @stream_ctxs[stream_id] = ctx
        end

        stream = ctx.stream
        stream.rx << frame
        []
      when FrameType::PUSH_PROMISE
        # TODO
      when FrameType::RST_STREAM
        self.class.handle_rst_stream(frame, @stream_ctxs)
        []
      when FrameType::WINDOW_UPDATE
        self.class.handle_window_update(frame, @send_window, @stream_ctxs)
        @data_buffer.take!(@send_window, @stream_ctxs)
      end
    rescue Error::StreamError => e
      [e.rst_stream]
    end
    # rubocop: enable Metrics/AbcSize
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/PerceivedComplexity

    # @param io [IO]
    def send_loop(io)
      loop do
        txs = @stream_ctxs.filter { |_, ctx| !ctx.closed? }.values.map(&:tx)
        break if txs.empty?

        _, pair = Ractor.select(*txs)
        send_frame, state = pair
        send_frame = send_frame.encode(@encoder) if send_frame.is_a?(Frame::RawHeaders) || send_frame.is_a?(Frame::RawContinuation)
        self.class.send(io, send_frame, @send_window, @stream_ctxs, @data_buffer)

        @stream_ctxs[send_frame.stream_id].state = state
        self.class.close_streams(@stream_ctxs, @data_buffer)
      end
    end

    # @return [Integer]
    def last_stream_id
      @stream_ctxs.keys.max || 0
    end

    # @param stream_ctxs [Hash<Integer, StreamContext>]
    # @param data_buffer [DataBuffer]
    def self.close_streams(stream_ctxs, data_buffer)
      closed_ids = stream_ctxs.filter { |_, ctx| ctx.closed? }.keys
      closed_ids.filter! { |id| !data_buffer.has?(id) }
      closed_ids.each { |id| close_stream(id, stream_ctxs) }
    end

    # @param id [Integer] stream_id
    # @param stream_ctxs [Hash<Integer, StreamContext>]
    def self.close_stream(id, stream_ctxs)
      stream_ctxs[id].stream.rx.close_incoming
      stream_ctxs[id].tx.close_incoming
      stream_ctxs.delete(id)
    end

    # @param io [IO]
    # @param frame [Object]
    # @param flush [Boolean]
    def self.do_send(io, frame, flush)
      io.write(frame.to_binary_s)
      io.flush if flush
    end

    # @param io [IO]
    # @param frame [Object]
    # @param send_window [Window]
    # @param stream_ctxs [Hash<Integer, StreamContext>]
    # @param data_buffer [DataBuffer]
    def self.send(io, frame, send_window, stream_ctxs, data_buffer)
      if frame.f_type != FrameType::DATA
        do_send(io, frame, false)
        return
      end

      data = frame
      if sendable?(data, send_window, stream_ctxs)
        do_send(io, data, false)
        send_window.consume!(data.length)
        stream_ctxs[data.stream_id].send_window.consume!(data.length)
        return
      end

      data_buffer << data
    end

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

    # @param io [IO]
    #
    # @raise ConnectionError
    def self.read_http2_magic(io)
      s = io.read(CONNECTION_PREFACE_LENGTH)
      raise Error::ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid connection preface') if s != CONNECTION_PREFACE
    end

    # @param rst_stream [RstStream]
    # @param stream_ctxs [Hash<Integer, StreamContext>]
    def self.handle_rst_stream(rst_stream, stream_ctxs)
      stream_id = rst_stream.stream_id
      stream_ctxs[stream_id].state = :closed
    end

    # @param settings [Settings]
    # @param send_settings [Hash<Integer, Integer>]
    # @param decoder [Decoder]
    #
    # @return [Settings, nil]
    # @return [Integer]
    def self.handle_settings(settings, send_settings, decoder)
      return nil if settings.ack?

      send_settings.merge!(settings.setting.to_h)
      decoder.limit!(send_settings[SettingsID::SETTINGS_HEADER_TABLE_SIZE])
      [Frame::Settings.new(true, []), send_settings[SettingsID::SETTINGS_MAX_CONCURRENT_STREAMS]]
    end

    # @param ping [Ping]
    #
    # @return [Ping, nil]
    def self.handle_ping(ping)
      Frame::Ping.new(true, ping.opaque) unless ping.ack?
    end

    # @param _goaway [Goaway]
    def self.handle_goaway(_goaway); end

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

    # @return [Hash<Integer, Integer>]
    def self.default_settings
      # https://datatracker.ietf.org/doc/html/rfc9113#section-6.5.2
      {
        SettingsID::SETTINGS_HEADER_TABLE_SIZE => 4_096,
        SettingsID::SETTINGS_ENABLE_PUSH => 1,
        SettingsID::SETTINGS_MAX_CONCURRENT_STREAMS => 0xffffffff,
        SettingsID::SETTINGS_INITIAL_WINDOW_SIZE => 65_535,
        SettingsID::SETTINGS_MAX_FRAME_SIZE => 16_384,
        SettingsID::SETTINGS_MAX_HEADER_LIST_SIZE => 0xffffffff
      }
    end
  end
end
