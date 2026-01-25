module Biryani
  module FrameType
    DATA          = 0x00
    HEADERS       = 0x01
    PRIORITY      = 0x02
    RST_STREAM    = 0x03
    SETTINGS      = 0x04
    PUSH_PROMISE  = 0x05
    PING          = 0x06
    GOAWAY        = 0x07
    WINDOW_UPDATE = 0x08
    CONTINUATION  = 0x09

    # @return [Boolean]
    def self.unknown?(typ)
      typ.negative? || typ > 0x09
    end
  end

  module ErrorCode
    NO_ERROR            = 0x00
    PROTOCOL_ERROR      = 0x01
    INTERNAL_ERROR      = 0x02
    FLOW_CONTROL_ERROR  = 0x03
    SETTINGS_TIMEOUT    = 0x04
    STREAM_CLOSED       = 0x05
    FRAME_SIZE_ERROR    = 0x06
    REFUSED_STREAM      = 0x07
    CANCEL              = 0x08
    COMPRESSION_ERROR   = 0x09
    CONNECT_ERROR       = 0x0a
    ENHANCE_YOUR_CALM   = 0x0b
    INADEQUATE_SECURITY = 0x0c
    HTTP_1_1_REQUIRED   = 0x0d
  end

  module Frame
    # @param s [String]
    #
    # @return [Integer]
    # @return [Integer]
    # @return [Integer]
    # @return [Integer]
    def self.read_header(s)
      b0, b1, b2, f_type, flags, stream_id = s.unpack('CCCCCN')
      payload_length = (b0 << 16) | (b1 << 8) | b2
      stream_id %= 2**31 # Stream Identifier (31)

      [payload_length, f_type, flags, stream_id]
    end

    # @param uint8 [Integer]
    #
    # @return [Boolean]
    def self.read_priority(uint8)
      (uint8 & 0b00100000).positive?
    end

    # @param uint8 [Integer]
    #
    # @return [Boolean]
    def self.read_padded(uint8)
      (uint8 & 0b00001000).positive?
    end

    # @param uint8 [Integer]
    #
    # @return [Boolean]
    def self.read_end_headers(uint8)
      (uint8 & 0b00000100).positive?
    end

    # @param uint8 [Integer]
    #
    # @return [Boolean]
    def self.read_end_stream(uint8)
      (uint8 & 0b00000001).positive?
    end

    # @param uint8 [Integer]
    #
    # @return [Boolean]
    def self.read_ack(uint8)
      (uint8 & 0b00000001).positive?
    end

    # @return [Integer]
    def self.to_flags(priority: false, padded: false, end_headers: false, end_stream: false, ack: false)
      (priority ? 32 : 0) + (padded ? 8 : 0) + (end_headers ? 4 : 0) + (end_stream || ack ? 1 : 0)
    end

    # @param payload_length [Integer]
    # @param f_type [Integer]
    # @param flags [Integer]
    # @param stream_id
    #
    # @return [String]
    def self.to_binary_s_header(payload_length, f_type, flags, stream_id)
      [payload_length, f_type, flags, stream_id].pack('NCCN')[1..]
    end
  end
end

require_relative 'frame/continuation'
require_relative 'frame/data'
require_relative 'frame/goaway'
require_relative 'frame/headers'
require_relative 'frame/ping'
require_relative 'frame/priority'
require_relative 'frame/push_promise'
require_relative 'frame/rst_stream'
require_relative 'frame/settings'
require_relative 'frame/unknown'
require_relative 'frame/window_update'

module Biryani
  module Frame
    FRAME_MAP = {
      FrameType::DATA => Data,
      FrameType::HEADERS => Headers,
      FrameType::PRIORITY => Priority,
      FrameType::RST_STREAM => RstStream,
      FrameType::SETTINGS => Settings,
      FrameType::PUSH_PROMISE => PushPromise,
      FrameType::PING => Ping,
      FrameType::GOAWAY => Goaway,
      FrameType::WINDOW_UPDATE => WindowUpdate,
      FrameType::CONTINUATION => Continuation
    }.freeze

    private_constant :FRAME_MAP
    Ractor.make_shareable(FRAME_MAP)

    # @param io [IO]
    #
    # @return [Object, nil, ConnectionError] frame or error
    def self.read(io)
      s = io.read(9)
      return nil if s.nil?
      return ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'invalid header length') if s.bytesize != 9

      payload_length, f_type, flags, stream_id = read_header(s)
      payload = io.read(payload_length)
      return ConnectionError.new(ErrorCode::PROTOCOL_ERROR, 'invalid frame') if payload.bytesize != payload_length
      return Frame::Unknown.new(f_type, flags, stream_id, payload) unless FRAME_MAP.key?(f_type)

      FRAME_MAP[f_type].read(payload, flags, stream_id)
    rescue StandardError
      ConnectionError.new(ErrorCode::FRAME_SIZE_ERROR, 'invalid frame')
    end
  end
end
