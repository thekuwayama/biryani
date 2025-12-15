module Biryani
  module SettingsID
    SETTINGS_HEADER_TABLE_SIZE      = 0x0001
    SETTINGS_ENABLE_PUSH            = 0x0002
    SETTINGS_MAX_CONCURRENT_STREAMS = 0x0003
    SETTINGS_INITIAL_WINDOW_SIZE    = 0x0004
    SETTINGS_MAX_FRAME_SIZE         = 0x0005
    SETTINGS_MAX_HEADER_LIST_SIZE   = 0x0006
  end

  # rubocop: disable Metrics/ClassLength
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
      @closed = false
    end

    # @param io [IO]
    def serve(io)
      self.class.read_http2_magic(io)
      self.class.do_send(io, Frame::Settings.new(false, []), true)

      loop do
        recv_frame = Frame.read(io)
        dispatch(recv_frame).each do |obj|
          reply_frame = self.class.ensure_frame(obj, last_stream_id)
          self.class.do_send(io, reply_frame, true)
          close if self.class.transition_state(reply_frame, @stream_ctxs)
        end

        send_loop(io)
        self.class.delete_streams(@stream_ctxs, @data_buffer)
        break if io.eof? || closed?
      end
    rescue StandardError
      self.class.do_send(io, Frame::Goaway.new(last_stream_id, ErrorCode::INTERNAL_ERROR, 'internal error'), true)
    ensure
      self.class.close_all_streams(@stream_ctxs)
    end

    # @param frame [Object]
    #
    # @return [Array<Object>, Error] frames or error
    def dispatch(frame)
      if frame.stream_id.zero?
        handle_connection_frame(frame)
      else
        handle_stream_frame(frame)
      end
    end

    # @param frame [Object]
    #
    # @return [Array<Object>, Error] frames or error
    # rubocop: disable Metrics/CyclomaticComplexity
    def handle_connection_frame(frame)
      typ = frame.f_type
      case typ
      when FrameType::DATA, FrameType::HEADERS, FrameType::PRIORITY, FrameType::RST_STREAM, FrameType::PUSH_PROMISE, FrameType::CONTINUATION
        Error::ConnectionError.new(ErrorCode::PROTOCOL_ERROR, "invalid frame type #{format('0x%02x', typ)} for stream identifier 0x00")
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
      else
        # ignore unknown frame type
        []
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
        Error::ConnectionError.new(ErrorCode::PROTOCOL_ERROR, "invalid frame type #{format('0x%02x', typ)} for stream identifier #{format('0x%02x', stream_id)}")
      when FrameType::DATA, FrameType::HEADERS, FrameType::PRIORITY, FrameType::CONTINUATION
        obj = frame.decode(@decoder) if typ == FrameType::HEADERS || FrameType::CONTINUATION
        return obj if obj.is_a?(Error::ConnectionError)

        frame = obj
        ctx = @stream_ctxs[stream_id]
        return Error::StreamError.new(ErrorCode::PROTOCOL_ERROR, stream_id, 'exceed max concurrent streams') if ctx.nil? && @stream_ctxs.values.filter(&:active?).length + 1 > @max_streams

        if ctx.nil?
          ctx = StreamContext.new
          @stream_ctxs[stream_id] = ctx
        end

        stream = ctx.stream
        stream.rx << frame
        ctx.state.transition!(frame, :recv)
        []
      when FrameType::PUSH_PROMISE
        # TODO
      when FrameType::RST_STREAM
        self.class.handle_rst_stream(frame, @stream_ctxs)
        []
      when FrameType::WINDOW_UPDATE
        self.class.handle_window_update(frame, @send_window, @stream_ctxs)
        @data_buffer.take!(@send_window, @stream_ctxs)
      else
        # ignore unknown frame type
        []
      end
    end
    # rubocop: enable Metrics/AbcSize
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/PerceivedComplexity

    # @param io [IO]
    # rubocop: disable Metrics/CyclomaticComplexity
    def send_loop(io)
      loop do
        errs = @stream_ctxs.values.map(&:err)
        txs = @stream_ctxs.values.filter { |ctx| !ctx.closed? }.map(&:tx)
        ports = errs + txs
        break if ports.empty?

        _, obj = Ractor.select(*ports)
        send_frame = self.class.ensure_frame(obj, last_stream_id)
        send_frame = send_frame.encode(@encoder) if send_frame.is_a?(Frame::RawHeaders) || send_frame.is_a?(Frame::RawContinuation)
        close if self.class.send(io, send_frame, @send_window, @stream_ctxs, @data_buffer)
      end
    end
    # rubocop: enable Metrics/CyclomaticComplexity

    # @return [Integer]
    def last_stream_id
      @stream_ctxs.keys.max || 0
    end

    def close
      @closed = true
    end

    # @return [Boolean]
    def closed?
      @closed
    end

    # @param obj [Object] frame or error
    # @param last_stream_id [Integer]
    #
    # @return [Frame]
    def self.ensure_frame(obj, last_stream_id)
      case obj
      when Error::ConnectionError
        obj.goaway(last_stream_id)
      when Error::StreamError
        obj.rst_stream
      else
        obj
      end
    end

    # @param send_frame [Frame]
    # @param stream_ctxs [Hash<Integer, StreamContext>]
    #
    # @return [Boolean] should close connection?
    def self.transition_state(send_frame, stream_ctxs)
      stream_id = send_frame.stream_id
      typ = send_frame.f_type
      stream_ctxs[stream_id].state.transition!(send_frame, :send) unless stream_id.zero?
      if typ == FrameType::GOAWAY
        close_all_streams(stream_ctxs)
        return true
      end

      if typ == FrameType::RST_STREAM
        stream_ctxs[stream_id].state.close
        close_stream(stream_id, stream_ctxs)
      end

      false
    end

    # @param id [Integer] stream_id
    # @param stream_ctxs [Hash<Integer, StreamContext>]
    def self.close_stream(id, stream_ctxs)
      ctx = stream_ctxs[id]
      ctx.stream.rx.close_incoming
      ctx.tx.close_incoming
      ctx.err.close_incoming
    end

    # @param stream_ctxs [Hash<Integer, StreamContext>]
    def self.close_all_streams(stream_ctxs)
      stream_ctxs.each_value do |ctx|
        ctx.stream.rx.close_incoming
        ctx.tx.close_incoming
        ctx.err.close_incoming
      end
    end

    # @param stream_ctxs [Hash<Integer, StreamContext>]
    # @param data_buffer [DataBuffer]
    def self.delete_streams(stream_ctxs, data_buffer)
      closed_ids = stream_ctxs.filter { |_, ctx| ctx.closed? }.keys
      closed_ids.filter! { |id| !data_buffer.has?(id) }
      closed_ids.each do |id|
        stream_ctxs[id].stream.rx.close_incoming
        stream_ctxs[id].tx.close_incoming
        stream_ctxs[id].err.close_incoming
        stream_ctxs.delete(id)
      end
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
    #
    # @return [Boolean] should close connection?
    def self.send(io, frame, send_window, stream_ctxs, data_buffer)
      if frame.f_type != FrameType::DATA
        do_send(io, frame, false)
        return transition_state(frame, stream_ctxs)
      end

      data = frame
      if sendable?(data, send_window, stream_ctxs)
        do_send(io, data, false)
        send_window.consume!(data.length)
        stream_ctxs[data.stream_id].send_window.consume!(data.length)
        return false
      end

      data_buffer << data
      false
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
    # @return [nil, Error]
    def self.read_http2_magic(io)
      s = io.read(CONNECTION_PREFACE_LENGTH)
      Error::ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid connection preface') if s != CONNECTION_PREFACE
    end

    # @param rst_stream [RstStream]
    # @param stream_ctxs [Hash<Integer, StreamContext>]
    def self.handle_rst_stream(rst_stream, stream_ctxs)
      stream_id = rst_stream.stream_id
      stream_ctxs[stream_id].state.close
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
  # rubocop: enable Metrics/ClassLength
end
