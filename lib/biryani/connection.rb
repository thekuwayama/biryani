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

    # proc [Proc]
    def initialize(proc)
      @sock = nil # Ractor
      @proc = proc
      @streams_ctx = StreamsContext.new
      @encoder = HPACK::Encoder.new(4_096)
      @decoder = HPACK::Decoder.new(4_096)
      @send_window = Window.new(65_535)
      @recv_window = Window.new(65_535)
      @data_buffer = DataBuffer.new
      @settings = self.class.default_settings # Hash<Integer, Integer>
      @peer_settings = self.class.default_settings # Hash<Integer, Integer>
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
      io&.close_write
    end

    # @param io [IO]
    def recv_loop(io)
      Ractor.new(io, @sock = Ractor::Port.new) do |io_, sock_|
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
    # rubocop: disable Metrics/MethodLength
    # rubocop: disable Metrics/PerceivedComplexity
    def send_loop(io)
      loop do
        ports = @streams_ctx.txs
        ports << @sock
        next if ports.empty?

        port, obj = Ractor.select(*ports)
        if port == @sock
          if obj.is_a?(StreamError) || obj.is_a?(ConnectionError)
            reply_frame = self.class.unwrap(obj, @streams_ctx.last_stream_id)
            self.class.do_send(io, reply_frame, true)
            close if self.class.transition_state_send(reply_frame, @streams_ctx)
          elsif obj.length > @settings[SettingsID::SETTINGS_MAX_FRAME_SIZE]
            self.class.do_send(io, Frame::Goaway.new(0, @streams_ctx.last_stream_id, ErrorCode::FRAME_SIZE_ERROR, 'payload length greater than SETTINGS_MAX_FRAME_SIZE'), true)
            close
          else
            recv_dispatch(obj).each do |frame|
              reply_frame = self.class.unwrap(frame, @streams_ctx.last_stream_id)
              self.class.do_send(io, reply_frame, true)
              close if self.class.transition_state_send(reply_frame, @streams_ctx)
            end
          end
        else
          res, stream_id = obj
          fragment, data = self.class.http_response(res, @encoder)
          max_frame_size = @peer_settings[SettingsID::SETTINGS_MAX_FRAME_SIZE]
          self.class.send_headers(io, stream_id, fragment, data.empty?, max_frame_size, @streams_ctx)
          self.class.send_data(io, stream_id, data, @send_window, max_frame_size, @streams_ctx, @data_buffer) unless data.empty?

          self.class.remove_closed_streams(@streams_ctx, @data_buffer)
        end

        break if closed?
      end
    ensure
      self.class.clear_all_streams(@streams_ctx)
    end
    # rubocop: enable Metrics/AbcSize
    # rubocop: enable Metrics/BlockLength
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/MethodLength
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
        obj = self.class.handle_settings(frame, @peer_settings, @decoder, @streams_ctx)
        return [] if obj.nil?

        settings_ack = obj
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

        max_frame_size = @peer_settings[SettingsID::SETTINGS_MAX_FRAME_SIZE]
        @data_buffer.take!(@send_window, @streams_ctx, max_frame_size)
      else
        # ignore unknown frame type
        []
      end
    end
    # rubocop: enable Metrics/CyclomaticComplexity

    # @param frame [Object]
    #
    # @return [Array<Object>, Array<ConnectionError>, Array<StreamError>] frames or errors
    # rubocop: disable Metrics/AbcSize
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/MethodLength
    # rubocop: disable Metrics/PerceivedComplexity
    def handle_stream_frame(frame)
      stream_id = frame.stream_id
      typ = frame.f_type
      return [ConnectionError.new(ErrorCode::PROTOCOL_ERROR, "invalid frame type #{format('0x%02x', typ)} for stream identifier #{format('0x%02x', stream_id)}")] \
        if [FrameType::SETTINGS, FrameType::PING, FrameType::GOAWAY].include?(typ)

      max_streams = @peer_settings[SettingsID::SETTINGS_MAX_CONCURRENT_STREAMS]
      send_initial_window_size = @peer_settings[SettingsID::SETTINGS_INITIAL_WINDOW_SIZE]
      recv_initial_window_size = @settings[SettingsID::SETTINGS_INITIAL_WINDOW_SIZE]
      obj = self.class.transition_state_recv(frame, @streams_ctx, stream_id, max_streams, send_initial_window_size, recv_initial_window_size, @proc)
      return [obj] if obj.is_a?(StreamError) || obj.is_a?(ConnectionError)

      ctx = obj
      case typ
      when FrameType::DATA
        # TODO: flow-control using @recv_window & ctx.recv_window
        ctx.content << frame.data
        if ctx.state.half_closed_remote?
          obj = self.class.http_request(ctx.fragment.string, ctx.content.string, @decoder)
          return [obj] if obj.is_a?(StreamError) || obj.is_a?(ConnectionError)

          ctx.stream.rx << obj
        end

        []
      when FrameType::HEADERS, FrameType::CONTINUATION
        ctx.fragment << frame.fragment
        if ctx.state.half_closed_remote?
          obj = self.class.http_request(ctx.fragment.string, ctx.content.string, @decoder)
          return [obj] if obj.is_a?(StreamError) || obj.is_a?(ConnectionError)

          ctx.stream.rx << obj
        end

        []
      when FrameType::PRIORITY
        # ignore PRIORITY Frame
        []
      when FrameType::PUSH_PROMISE
        # TODO
        []
      when FrameType::RST_STREAM
        self.class.handle_rst_stream(frame, @streams_ctx)
        []
      when FrameType::WINDOW_UPDATE
        err = self.class.handle_stream_window_update(frame, @streams_ctx)
        return [err] unless err.nil?

        max_frame_size = @peer_settings[SettingsID::SETTINGS_MAX_FRAME_SIZE]
        @data_buffer.take!(@send_window, @streams_ctx, max_frame_size)
      else
        # ignore UNKNOWN Frame
        []
      end
    end
    # rubocop: enable Metrics/AbcSize
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/MethodLength
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
    def self.unwrap(obj, last_stream_id)
      case obj
      when ConnectionError
        obj.goaway(last_stream_id)
      when StreamError
        obj.rst_stream
      else
        obj
      end
    end

    # @param recv_frame [Object]
    # @param streams_ctx [StreamsContext]
    # @param stream_id [Integer]
    # @param max_streams [Integer]
    # @param send_initial_window_size [Integer]
    # @param recv_initial_window_size [Integer]
    # @param proc [Proc]
    #
    # @return [StreamContext, StreamError, ConnectionError]
    # rubocop: disable Metrics/CyclomaticComplexity
    # rubocop: disable Metrics/PerceivedComplexity
    def self.transition_state_recv(recv_frame, streams_ctx, stream_id, max_streams, send_initial_window_size, recv_initial_window_size, proc)
      ctx = streams_ctx[stream_id]
      return StreamError.new(ErrorCode::PROTOCOL_ERROR, stream_id, 'exceed max concurrent streams') if ctx.nil? && streams_ctx.count_active + 1 > max_streams
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'even-numbered stream identifier') if ctx.nil? && stream_id.even?
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'new stream identifier is less than the existing stream identifiers') if ctx.nil? && streams_ctx.last_stream_id > stream_id

      ctx = streams_ctx.new_context(stream_id, send_initial_window_size, recv_initial_window_size, proc) if ctx.nil?
      obj = ctx.state.transition!(recv_frame, :recv)
      return obj if obj.is_a?(StreamError) || obj.is_a?(ConnectionError)

      ctx
    end
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/PerceivedComplexity

    # @param send_frame [Object]
    # @param streams_ctx [StreamsContext]
    #
    # @return [Boolean] should close connection?
    def self.transition_state_send(send_frame, streams_ctx)
      stream_id = send_frame.stream_id
      typ = send_frame.f_type
      case typ
      when FrameType::SETTINGS, FrameType::PING
        false
      when FrameType::GOAWAY
        close_all_streams(streams_ctx)
        true
      else
        streams_ctx[stream_id].state.transition!(send_frame, :send)
        false
      end
    end

    # @param streams_ctx [StreamsContext]
    def self.clear_all_streams(streams_ctx)
      streams_ctx.each do |ctx|
        ctx.tx.close
        ctx.stream.rx << nil
        ctx.fragment.close
        ctx.content.close
      end
    end

    # @param streams_ctx [StreamsContext]
    def self.close_all_streams(streams_ctx)
      streams_ctx.each do |ctx|
        ctx.tx.close
        ctx.fragment.close
        ctx.content.close
        ctx.state.close
      end
    end

    # @param streams_ctx [StreamsContext]
    # @param data_buffer [DataBuffer]
    def self.remove_closed_streams(streams_ctx, data_buffer)
      closed_ids = streams_ctx.closed_stream_ids.filter { |id| !data_buffer.has?(id) }
      closed_ids.each do |id|
        streams_ctx[id].tx.close
        streams_ctx[id].stream.rx << nil
        streams_ctx[id].fragment.close
        streams_ctx[id].content.close
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
    # @param stream_id [Integer]
    # @param data [String]
    # @param send_window [Window]
    # @param max_frame_size [Integer]
    # @param streams_ctx [StreamsContext]
    # @param data_buffer [DataBuffer]
    def self.send_data(io, stream_id, data, send_window, max_frame_size, streams_ctx, data_buffer)
      frames, remains = sendable_data_frames(data, stream_id, send_window, max_frame_size, streams_ctx)

      frames.each do |frame|
        do_send(io, frame, false)
        send_window.consume!(frame.length)
        streams_ctx[stream_id].send_window.consume!(frame.length)
        transition_state_send(frame, streams_ctx)
      end

      data_buffer.store(stream_id, remains) unless remains.empty?
    end

    # @param io [IO]
    # @param stream_id [Integer]
    # @param fragment [String]
    # @param only_headers [Boolean]
    # @param max_frame_size [Integer]
    # @param streams_ctx [StreamsContext]
    def self.send_headers(io, stream_id, fragment, only_headers, max_frame_size, streams_ctx)
      len = (fragment.bytesize + max_frame_size - 1) / max_frame_size
      frames = fragment.gsub(/.{1,#{max_frame_size}}/m).with_index.map do |s, index|
        end_headers = index == len - 1
        if index.zero?
          Frame::Headers.new(end_headers, only_headers, stream_id, nil, nil, s, nil)
        else
          Frame::Continuation.new(end_headers, stream_id, s)
        end
      end

      frames.each do |frame|
        do_send(io, frame, false)
        transition_state_send(frame, streams_ctx)
      end
    end

    # @param data [String]
    # @param stream_id [Integer]
    # @param send_window [Window]
    # @param max_frame_size [Integer]
    # @param streams_ctx [StreamsContext]
    #
    # @return [Array<Object>] frames
    # @return [String]
    def self.sendable_data_frames(data, stream_id, send_window, max_frame_size, streams_ctx)
      len = [data.bytesize, send_window.length, streams_ctx[stream_id].send_window.length].min

      payload = data[0...len]
      remains = data[len..] || ''

      len = (len + max_frame_size - 1) / max_frame_size
      frames = payload.gsub(/.{1,#{max_frame_size}}/m).with_index.map do |s, index|
        end_stream = remains.empty? && index == len - 1
        Frame::Data.new(end_stream, stream_id, s, nil)
      end

      [frames, remains]
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
    # @param peer_settings [Hash<Integer, Integer>]
    # @param decoder [Decoder]
    #
    # @return [Settings]
    def self.handle_settings(settings, peer_settings, decoder, streams_ctx)
      return nil if settings.ack?

      peer_settings.merge!(settings.setting)
      new_limit = peer_settings[SettingsID::SETTINGS_HEADER_TABLE_SIZE]
      decoder.limit!(new_limit)
      send_initial_window_size = peer_settings[SettingsID::SETTINGS_INITIAL_WINDOW_SIZE]
      streams_ctx.each do |ctx|
        ctx.send_window.update!(send_initial_window_size)
      end

      Frame::Settings.new(true, 0, {})
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
      # TODO: send WINDOW_UPDATE to do the flow-conrol
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

    # @param fragment [String]
    # @param content [String]
    # @param decoder [Decoder]
    #
    # @return [HTTPRequest, ConnectionError]
    def self.http_request(fragment, content, decoder)
      obj = decoder.decode(fragment)
      return obj if obj.is_a?(StreamError) || obj.is_a?(ConnectionError)

      fields = obj
      builder = HTTPRequestBuilder.new
      err = builder.fields(fields)
      return err unless err.nil?

      builder.build(content)
    end

    # @param res [HTTPResponse]
    # @param encoder [Encoder]
    #
    # @return [String] fragment
    # @return [String] data
    def self.http_response(res, encoder)
      HTTPResponseParser.new(res).parse(encoder)
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
