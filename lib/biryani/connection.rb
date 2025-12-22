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
    include Port
    CONNECTION_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".freeze
    CONNECTION_PREFACE_LENGTH = CONNECTION_PREFACE.length

    private_constant :CONNECTION_PREFACE, :CONNECTION_PREFACE_LENGTH
    Ractor.make_shareable(CONNECTION_PREFACE)
    Ractor.make_shareable(CONNECTION_PREFACE_LENGTH)

    def initialize
      @sock = nil # Ractor
      @max_streams = 0xffffffff
      @max_frame_size = 16_384
      @streams_ctx = StreamsContext.new
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
      err = self.class.read_http2_magic(io)
      unless err.nil?
        self.class.do_send(io, err.goaway(@streams_ctx.last_stream_id), true)
        return
      end

      self.class.do_send(io, Frame::Settings.new(false, 0, {}), true)

      recv_loop(io.clone)
      send_loop(io)
    rescue StandardError
      self.class.do_send(io, Frame::Goaway.new(0, @streams_ctx.last_stream_id, ErrorCode::INTERNAL_ERROR, 'internal error'), true)
    ensure
      self.class.close_all_streams(@streams_ctx)
      io&.close_write
    end

    # @param io [IO]
    def recv_loop(io)
      Ractor.new(io, @sock = port) do |io_, sock_|
        loop do
          obj = Frame.read(io_)
          break if obj.nil?

          sock_ << obj
        end
      end
    end

    # @param io [IO]
    # rubocop: disable Metrics/AbcSize
    # rubocop: disable Metrics/BlockLength
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/PerceivedComplexity
    def send_loop(io)
      loop do
        ports = @streams_ctx.txs + @streams_ctx.errs
        ports << @sock
        break if ports.empty?

        port_, obj = Ractor.select(*ports)
        if port_ == @sock
          if obj.is_a?(ConnectionError) || obj.is_a?(StreamError)
            reply_frame = self.class.ensure_frame(obj, @streams_ctx.last_stream_id)
            self.class.do_send(io, reply_frame, true)
            close if self.class.transition_state(reply_frame, @streams_ctx)
          elsif obj.length > @max_frame_size
            self.class.do_send(io, Frame::Goaway.new(0, @streams_ctx.last_stream_id, ErrorCode::FRAME_SIZE_ERROR, 'payload length greater than SETTINGS_MAX_FRAME_SIZE'), true)
            close
          elsif [FrameType::GOAWAY, FrameType::RST_STREAM].include?(obj.f_type)
            close if self.class.transition_state(obj, @streams_ctx)
          else
            recv_dispatch(obj).each do |frame|
              reply_frame = self.class.ensure_frame(frame, @streams_ctx.last_stream_id)
              self.class.do_send(io, reply_frame, true)
              close if self.class.transition_state(reply_frame, @streams_ctx)
            end
          end
        else
          send_frame = self.class.ensure_frame(obj, @streams_ctx.last_stream_id)
          send_frame = send_frame.encode(@encoder) if send_frame.is_a?(Frame::RawHeaders) || send_frame.is_a?(Frame::RawContinuation)
          close if self.class.send(io, send_frame, @send_window, @streams_ctx, @data_buffer)

          self.class.delete_streams(@streams_ctx, @data_buffer)
        end

        break if closed?
      end
    end
    # rubocop: enable Metrics/AbcSize
    # rubocop: enable Metrics/BlockLength
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/PerceivedComplexity

    # @param frame [Object]
    #
    # @return [Array<Object>, Array<ConnectionError>, Array<StreamError>] frames or errors
    def recv_dispatch(frame)
      if frame.stream_id.zero?
        handle_connection_frame(frame)
      else
        handle_stream_frame(frame)
      end
    end

    # @param frame [Object]
    #
    # @return [Array<Object>, Array<ConnectionError>, Array<StreamError>] frames or errors
    # rubocop: disable Metrics/CyclomaticComplexity
    def handle_connection_frame(frame)
      typ = frame.f_type
      case typ
      when FrameType::DATA, FrameType::HEADERS, FrameType::PRIORITY, FrameType::RST_STREAM, FrameType::PUSH_PROMISE, FrameType::CONTINUATION
        [ConnectionError.new(ErrorCode::PROTOCOL_ERROR, "invalid frame type #{format('0x%02x', typ)} for stream identifier 0x00")]
      when FrameType::SETTINGS
        obj = self.class.handle_settings(frame, @send_settings, @decoder)
        return [] if obj.nil?
        return [obj] if obj.is_a?(ConnectionError)

        settings_ack, @max_streams, @max_frame_size = obj
        [settings_ack]
      when FrameType::PING
        obj = self.class.handle_ping(frame)
        return [] if obj.nil?

        [obj]
      when FrameType::GOAWAY
        self.class.handle_goaway(frame)
        # TODO: logging error
        []
      when FrameType::WINDOW_UPDATE
        err = self.class.handle_connection_window_update(frame, @send_window)
        return [err] unless err.nil?

        @data_buffer.take!(@send_window, @streams_ctx)
      else
        # ignore unknown frame type
        []
      end
    end
    # rubocop: enable Metrics/CyclomaticComplexity

    # @param frame [Object]
    #
    # @return [Array<Object>, Array<ConnectionError>, Array<StreamError>] frames or errors
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/PerceivedComplexity
    def handle_stream_frame(frame)
      stream_id = frame.stream_id
      typ = frame.f_type
      case typ
      when FrameType::SETTINGS, FrameType::PING, FrameType::GOAWAY
        [ConnectionError.new(ErrorCode::PROTOCOL_ERROR, "invalid frame type #{format('0x%02x', typ)} for stream identifier #{format('0x%02x', stream_id)}")]
      when FrameType::DATA, FrameType::HEADERS, FrameType::CONTINUATION
        if [FrameType::HEADERS, FrameType::CONTINUATION].include?(typ)
          obj = frame.decode(@decoder)
          return [obj] if obj.is_a?(ConnectionError)

          frame = obj
        end

        ctx = @streams_ctx[stream_id]
        return [StreamError.new(ErrorCode::PROTOCOL_ERROR, stream_id, 'exceed max concurrent streams')] if ctx.nil? && @streams_ctx.count_active + 1 > @max_streams

        ctx = @streams_ctx.new_context(stream_id) if ctx.nil?
        ctx.stream.rx << frame
        ctx.state.transition!(frame, :recv)
        []
      when FrameType::PRIORITY
        # ignore
        []
      when FrameType::PUSH_PROMISE
        # TODO
      when FrameType::RST_STREAM
        self.class.handle_rst_stream(frame, @streams_ctx)
        []
      when FrameType::WINDOW_UPDATE
        err = self.class.handle_stream_window_update(frame, @streams_ctx)
        return [err] unless err.nil?

        @data_buffer.take!(@send_window, @streams_ctx)
      else
        # ignore unknown frame type
        []
      end
    end
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/PerceivedComplexity

    def close
      @closed = true
    end

    # @return [Boolean]
    def closed?
      @closed
    end

    # @param obj [Object, ConnectionError, StreamError] frame or error
    # @param last_stream_id [Integer]
    #
    # @return [Frame]
    def self.ensure_frame(obj, last_stream_id)
      case obj
      when ConnectionError
        obj.goaway(last_stream_id)
      when StreamError
        obj.rst_stream
      else
        obj
      end
    end

    # @param send_frame [Frame]
    # @param streams_ctx [StreamsContext]
    #
    # @return [Boolean] should close connection?
    def self.transition_state(send_frame, streams_ctx)
      stream_id = send_frame.stream_id
      typ = send_frame.f_type
      streams_ctx[stream_id].state.transition!(send_frame, :send) unless stream_id.zero?
      if typ == FrameType::GOAWAY
        close_all_streams(streams_ctx)
        return true
      end

      if typ == FrameType::RST_STREAM
        streams_ctx[stream_id].state.close
        close_stream(stream_id, streams_ctx)
      end

      false
    end

    # @param id [Integer] stream_id
    # @param streams_ctx [StreamsContext]
    def self.close_stream(id, streams_ctx)
      streams_ctx[id].stream.rx.close_incoming
      streams_ctx[id].tx.close_incoming
      streams_ctx[id].err.close_incoming
    end

    # @param streams_ctx [StreamsContext]
    def self.close_all_streams(streams_ctx)
      streams_ctx.each do |ctx|
        ctx.stream.rx.close_incoming
        ctx.tx.close_incoming
        ctx.err.close_incoming
      end
    end

    # @param streams_ctx [StreamsContext]
    # @param data_buffer [DataBuffer]
    def self.delete_streams(streams_ctx, data_buffer)
      closed_ids = streams_ctx.closed_stream_ids
      closed_ids.filter! { |id| !data_buffer.has?(id) }
      closed_ids.each do |id|
        streams_ctx[id].stream.rx.close_incoming
        streams_ctx[id].tx.close_incoming
        streams_ctx[id].err.close_incoming
        streams_ctx.delete(id)
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
    # @param streams_ctx [StreamsContext]
    # @param data_buffer [DataBuffer]
    #
    # @return [Boolean] should close connection?
    def self.send(io, frame, send_window, streams_ctx, data_buffer)
      if frame.f_type != FrameType::DATA
        do_send(io, frame, false)
        return transition_state(frame, streams_ctx)
      end

      data = frame
      if sendable?(data, send_window, streams_ctx)
        do_send(io, data, false)
        send_window.consume!(data.length)
        streams_ctx[data.stream_id].send_window.consume!(data.length)
        return false
      end

      data_buffer << data
      false
    end

    # @param data [Data]
    # @param send_window [Window]
    # @param streams_ctx [StreamsContext]
    #
    # @return [Boolean]
    def self.sendable?(data, send_window, streams_ctx)
      length = data.length
      stream_id = data.stream_id
      send_window.available?(length) && streams_ctx[stream_id].send_window.available?(length)
    end

    # @param io [IO]
    #
    # @return [nil, Error]
    def self.read_http2_magic(io)
      s = io.read(CONNECTION_PREFACE_LENGTH)
      ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid connection preface') if s != CONNECTION_PREFACE
    end

    # @param rst_stream [RstStream]
    # @param streams_ctx [StreamsContext]
    def self.handle_rst_stream(rst_stream, streams_ctx)
      stream_id = rst_stream.stream_id
      streams_ctx[stream_id].state.close
    end

    # @param settings [Settings]
    # @param send_settings [Hash<Integer, Integer>]
    # @param decoder [Decoder]
    #
    # @return [Settings]
    # @return [Integer] max_streams
    # @return [Integer] max_frame_size
    def self.handle_settings(settings, send_settings, decoder)
      return nil if settings.ack?

      send_settings.merge!(settings.setting)
      decoder.limit!(send_settings[SettingsID::SETTINGS_HEADER_TABLE_SIZE])
      [
        Frame::Settings.new(true, 0, {}),
        send_settings[SettingsID::SETTINGS_MAX_CONCURRENT_STREAMS],
        send_settings[SettingsID::SETTINGS_MAX_FRAME_SIZE]
      ]
    end

    # @param ping [Ping]
    #
    # @return [Ping, nil, ConnectionError]
    def self.handle_ping(ping)
      Frame::Ping.new(true, 0, ping.opaque) unless ping.ack?
    end

    # @param _goaway [Goaway]
    def self.handle_goaway(_goaway); end

    # @param window_update [WindowUpdate]
    # @param send_window [Window]
    #
    # @return [nil, ConnectionError]
    def self.handle_connection_window_update(window_update, send_window)
      send_window.increase!(window_update.window_size_increment)
      nil
    end

    # @param window_update [WindowUpdate]
    # @param streams_ctx [StreamsContext]
    #
    # @return [nil, ConnectionError]
    def self.handle_stream_window_update(window_update, streams_ctx)
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'WINDOW_UPDATE invalid window size increment 0') if window_update.window_size_increment.zero?
      return StreamError.new(ErrorCode::FLOW_CONTROL_ERROR, window_update.stream_id, 'WINDOW_UPDATE invalid window size increment greater than 2^31-1') \
        if window_update.window_size_increment > 2**31 - 1

      streams_ctx[window_update.stream_id].send_window.increase!(window_update.window_size_increment)
      nil
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
