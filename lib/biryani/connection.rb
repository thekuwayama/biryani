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

        loop do
          txs = @stream_ctxs.values.map(&:tx)
          break if txs.empty?

          _, ss = Ractor.select(*txs)
          send_frame, state = ss
          send_frame = send_frame.encode(@encoder) if send_frame.is_a?(Frame::RawHeaders)
          self.class.send(io, send_frame, @send_window, @stream_ctxs, @data_buffer)

          @stream_ctxs[send_frame.stream_id].close if state == :closed
          self.class.close_streams(@stream_ctxs, @data_buffer)
        end

        break if io.eof?
      end
    end

    # @param frame [Object]
    #
    # @return [Array<Object>] frames
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
          settings_ack = self.class.handle_settings(frame, @send_settings)
          return [settings_ack] unless settings_ack.nil?

          []
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
      else
        if [FrameType::SETTINGS, FrameType::PING, FrameType::GOAWAY].include?(typ)
          abort 'protocol_error' # TODO: send error
        elsif typ == FrameType::HEADERS
          frame = frame.decode(@decoder)
        end

        ctx = @stream_ctxs[stream_id] || StreamContext.new
        stream = ctx.stream
        stream.rx << frame
        @stream_ctxs[stream_id] = ctx

        []
      end
    end
    # rubocop: enable Metrics/CyclomaticComplexity
    # rubocop: enable Metrics/MethodLength
    # rubocop: enable Metrics/PerceivedComplexity

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
    # @param send_settings [Hash<Integer, Integer>]
    #
    # @return [Settings, nil]
    def self.handle_settings(settings, send_settings)
      return nil if settings.ack?

      send_settings.merge!(settings.setting.to_h)
      Frame::Settings.new(true, [])
    end

    # @param _goaway [Goaway]
    def self.handle_goaway(_goaway); end

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
